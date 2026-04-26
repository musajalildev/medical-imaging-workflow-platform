require "google/apis/drive_v3"
require "googleauth"

class JobsController < ApplicationController
  load_and_authorize_resource param_method: :job_params
  MAX_FILE_SIZE_BYTES = 1_073_741_824 # 1 GB
  before_action :set_job, only: %i[ show edit update destroy upload_output update_status self_assign complete_job cancel_job ]
  before_action :check_client_role, only: %i[ new create edit update ]

  # GET /jobs
  def index
    # Checks for operator role
    if current_user&.operator?
      @tab = params[:tab].presence_in(%w[assigned unassigned]) || "assigned"
      if @tab == "unassigned"
        @jobs = Job.where(operator_id: nil)
      else
        @jobs = Job.where(operator_id: current_user.id)
      end
    end

    permitted = params.permit(:status, :search, :search_by, :sort, :_method, :authenticity_token, :tab, job: {})

    @jobs = @jobs.where(status: permitted[:status]) if permitted[:status].present?

    if permitted[:search].present?
      q = "%#{permitted[:search]}%"
      case permitted[:search_by]
      when 'title'
        @jobs = @jobs.where("jobs.title ILIKE :q", q: q)
      when 'client'
        @jobs = @jobs.joins(:client).where("users.givenname ILIKE :q OR users.sn ILIKE :q OR users.username ILIKE :q", q: q)
      when 'operator'
        @jobs = @jobs.joins("INNER JOIN users AS operators ON operators.id = jobs.operator_id")
                     .where("operators.givenname ILIKE :q OR operators.sn ILIKE :q OR operators.username ILIKE :q", q: q)
      else
        @jobs = @jobs.joins(:client).where("jobs.title ILIKE :q OR users.givenname ILIKE :q OR users.sn ILIKE :q OR users.username ILIKE :q", q: q)
      end
    end

    sort_dir = permitted[:sort] == 'asc' ? :asc : :desc
    @jobs = @jobs.order(created_at: sort_dir)
    @total_count = @jobs.count
  end

  # GET /jobs/1
  def show
    @user = current_user
  end

  # GET /jobs/new
  def new
    @job = Job.new
  end

  # GET /jobs/1/edit
  def edit
  end

  # POST /jobs
  def create
    @job = Job.new(job_params)
    @job.client = current_user

    if @job.save
      attach_uploaded_file(@job, ensure_placeholders: true)
      redirect_to @job, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update(job_params)
      attach_uploaded_file(@job, ensure_placeholders: false)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/update_status
  def update_status

    updated_params = job_params

    # normalize custom status
    updated_params[:custom_status] = updated_params[:custom_status]&.strip

    # clear custom status if status is changed to non-custom
    if updated_params[:status] != "custom"
      updated_params[:custom_status] = nil
    end

    # save old and new status for creating job status history record after update
    old_status = @job.get_status_for_display
    # returns humanized version of custom status if status is custom, otherwise returns humanized version of status enum
    new_status = (updated_params[:status] == "custom" ? updated_params[:custom_status] : updated_params[:status]).to_s.humanize

    if @job.update(updated_params)
      
      # create a job status history record if the status is changing
      if old_status != new_status
        JobStatusHistory.create!(
          job: @job,
          old_status: old_status,
          new_status: new_status,
          initiator: current_user
        )
        # send email to client if job status changed
        UserMailer.send_job_status_change_email(@job).deliver_later
      end

      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      redirect_to @job, status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/self_assign
  def self_assign
    puts "hello"
    if @job.operator_id.nil?
      @job.update!(operator: current_user, status: :assigned)
      # Automatically update job status when assigned
      JobStatusHistory.create!(
        job: @job,
        old_status: @job.status_before_last_save || "pending",
        new_status: "assigned",
        initiator: current_user
      ) if @job.saved_change_to_operator_id?
      redirect_to jobs_path(tab: "unassigned"), notice: "Job assigned to you.", status: :see_other
    else
      redirect_to jobs_path(tab: "unassigned"), alert: "Job is already assigned.", status: :see_other
    end
  end

  # PATCH /jobs/1/complete_job
  def complete_job
    if @job.update(status: :complete)
      UserMailer.send_job_completed_email(@job).deliver_later
      redirect_to @job, notice: "Job was successfully completed.", status: :see_other
    else
      redirect_to @job, alert: "Failed to complete job.", status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/cancel_job
  def cancel_job
    if @job.update(status: :cancelled)
      UserMailer.send_job_cancelled_email(@job).deliver_later
      redirect_to @job, notice: "Job was successfully cancelled.", status: :see_other
    else
      redirect_to @job, alert: "Failed to cancel job.", status: :unprocessable_entity
    end
  end

  # DELETE /jobs/1
  def destroy
    purge_error = purge_job_files_from_drive
    if purge_error.present?
      redirect_to @job, alert: "Job was not deleted because Drive cleanup failed: #{purge_error}"
      return
    end

    @job.destroy!
    redirect_to jobs_path, notice: "Job was successfully destroyed.", status: :see_other
  rescue StandardError => e
    redirect_to @job, alert: "Job delete failed: #{e.message}"
  end

  # POST /jobs/1/upload_output
  def upload_output
    unless current_user&.operator?
      redirect_to @job, alert: "Only operators can upload output files."
      return
    end

    file = params[:output_file]
    if file.blank?
      redirect_to @job, alert: "Please select an output file."
      return
    end
    validate_output_file!(file)

    drive_service = build_drive_service
    # Generate unique name with UUID prefix to avoid collisions
    generated_filename = "#{SecureRandom.uuid}-#{file.original_filename}"
    uploaded_file = drive_service.create_file(
      Google::Apis::DriveV3::File.new(name: generated_filename, parents: [FilesController::FOLDER_ID]),
      upload_source: file.tempfile,
      content_type: file.content_type.presence || "application/octet-stream",
      fields: "id, webViewLink, webContentLink",
      supports_all_drives: true
    )

    file_url = uploaded_file.web_view_link.presence || uploaded_file.web_content_link.presence || "https://drive.google.com/file/d/#{uploaded_file.id}/view"
    metadata = {
      file_id: uploaded_file.id,
      mime_type: file.content_type.presence,
      slot: "output"
    }.to_json

    output_image = @job.image_files.detect(&:output_file?) || @job.image_files.build
    output_image.file_path = file_url
    output_image.file_type = metadata
    output_image.save!

    redirect_to @job, notice: "Output file uploaded."
  rescue StandardError => e
    redirect_to @job, alert: "Output upload failed: #{e.message}"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_job
      @job = Job.find(params.expect(:id))
    end

    def authorize_job
      authorize! :manage, @job
    end

    # Only allow a list of trusted parameters through.
    def job_params
      case action_name  
      when "create"
        params.expect(job: [ :operator_id, :status, :title, :description, :custom_status ])
      when "update"
        params.expect(job: [ :operator_id, :title, :description ])
      when "update_status"
        params.expect(job: [ :status, :custom_status ])
      end
    end

    def attach_uploaded_file(job, ensure_placeholders: false)
      uploaded_files = JSON.parse(params[:uploaded_files_json].presence || "[]")
      if uploaded_files.blank?
        if ensure_placeholders
          existing_non_output = job.image_files.reject(&:output_file?).count
          [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
        end
        return
      end

      uploaded_files.first(2).each do |uploaded|
        file_id = uploaded["file_id"].presence
        file_url = uploaded["file_url"].presence
        file_path = file_url.presence || (file_id.present? ? "https://drive.google.com/file/d/#{file_id}/view" : nil)
        file_type = {
          file_id: file_id,
          mime_type: uploaded["file_type"].presence
        }.to_json

        image_file = job.image_files.build
        image_file.file_path = file_path
        image_file.file_type = file_type
        image_file.save!
      end

      if ensure_placeholders && uploaded_files.length < 2
        existing_non_output = job.image_files.reject(&:output_file?).count
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
      end
    rescue JSON::ParserError
      if ensure_placeholders
        existing_non_output = job.image_files.reject(&:output_file?).count
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
      end
    end

    def build_drive_service
      drive_service = Google::Apis::DriveV3::DriveService.new
      drive_service.client_options.application_name = "Rails Drive Upload"

      service_account_path = Rails.root.join("service_account.json")
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(service_account_path),
        scope: [Google::Apis::DriveV3::AUTH_DRIVE]
      )
      credentials.fetch_access_token!
      drive_service.authorization = credentials
      drive_service
    end

    def validate_output_file!(file)
      if file.size.to_i > MAX_FILE_SIZE_BYTES
        raise ArgumentError, "Report file exceeds 1 GB size limit."
      end

      extension = File.extname(file.original_filename.to_s).downcase
      raise ArgumentError, "Report file must have .pdf extension." unless extension == ".pdf"
    end

    def purge_job_files_from_drive
      file_ids = @job.image_files.filter_map(&:drive_file_id).uniq
      return nil if file_ids.empty?

      drive_service = build_drive_service

      file_ids.each do |file_id|
        begin
          purge_drive_file!(drive_service, file_id)
        rescue Google::Apis::ClientError => e
          next if e.status_code.to_i == 404

          return e.message
        end
      end

      nil
    end

    def purge_drive_file!(drive_service, file_id)
      metadata = drive_service.get_file(
        file_id,
        fields: "id,parents,capabilities(canDelete,canTrash)",
        supports_all_drives: true
      )

      if metadata.capabilities&.can_delete
        drive_service.delete_file(file_id, supports_all_drives: true)
      elsif metadata.capabilities&.can_trash
        drive_service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new(trashed: true),
          supports_all_drives: true,
          fields: "id"
        )
      elsif metadata.parents&.include?(FilesController::FOLDER_ID)
        drive_service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new,
          remove_parents: FilesController::FOLDER_ID,
          supports_all_drives: true,
          fields: "id"
        )
      else
        raise "Google Drive does not allow this service account to delete, trash, or remove file #{file_id} from the folder."
      end
    end

    def check_client_role
      unless current_user&.client?
        redirect_to jobs_path, alert: "Only clients can create or edit jobs."
      end
    end
end
