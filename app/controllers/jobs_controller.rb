require "google/apis/drive_v3"
require "googleauth"

class JobsController < ApplicationController
  load_and_authorize_resource param_method: :job_params, except: :upload_output
  MAX_FILE_SIZE_BYTES = 1_073_741_824 # 1 GB
  before_action :set_job, only: %i[ show edit update destroy upload_output update_status self_assign complete_job cancel_job ]
  # GET /jobs
  def index
    if current_user&.operator?
      @tab = params[:tab].presence_in(%w[assigned unassigned]) || "assigned"
      if @tab == "unassigned"
        @jobs = Job.where(status: :pending)
      else
        @jobs = Job.where(operator_id: current_user.id).where.not(status: :draft)
      end
    elsif current_user&.client?
      @tab = params[:tab].presence_in(%w[active drafts]) || "active"
      if @tab == "drafts"
        @jobs = Job.where(client_id: current_user.id, status: :draft)
      else
        @jobs = Job.where(client_id: current_user.id).where.not(status: :draft)
      end
    else # admin
      @jobs = Job.where.not(status: :draft)
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
    @tab = params[:tab].presence_in(%w[assigned unassigned]) || "assigned"
  end

  # GET /jobs/new
  def new
    @job = Job.new
    @submit_action = "create_job"
  end

  # GET /jobs/1/edit
  def edit
    @submit_action = "update_draft"
  end

  # POST /jobs
  def create
    @job = Job.new(job_params)
    @job.client = current_user
    @job.operator = nil

    # Only save_as_draft button can change status
    if params[:save_as_draft].present?
      @job.status = :draft
      Rails.logger.info('job has been set as draft!!!!') # Uncomment for logging if needed
    else
      @job.status = :pending
      Rails.logger.info ("Job has been submitted, validation should occur")
    end

    uploaded_files = begin
      JSON.parse(params[:uploaded_files_json].presence || "[]")
    rescue JSON::ParserError
      []
    end
    uploaded_pdf = uploaded_files.find { |entry| entry.is_a?(Hash) && entry["slot"].to_i == 1 }
    uploaded_dicom = uploaded_files.find { |entry| entry.is_a?(Hash) && entry["slot"].to_i == 2 }
    has_pdf_upload = uploaded_pdf.present? && (uploaded_pdf["file_id"].present? || uploaded_pdf["file_url"].present?)
    has_dicom_upload = if uploaded_dicom.present?
      dicom_entries = uploaded_dicom["files"]
      (uploaded_dicom["file_id"].present? || uploaded_dicom["file_url"].present?) ||
        (dicom_entries.is_a?(Array) && dicom_entries.any? { |f| f.is_a?(Hash) && f["file_id"].present? })
    else
      false
    end

    @job.valid?
    unless params[:save_as_draft].present?
      Rails.logger.info("Validation starting")

      if !has_pdf_upload || !has_dicom_upload
        @job.errors.add(:base, "Both input files (PDF and DICOM) must be uploaded")
      end
    end

    if @job.errors.empty? && @job.save
      attach_uploaded_file(@job, ensure_placeholders: !@job.draft?)
      unless @job.draft?
        # notify all operators of the new job
        User.where(role: :operator).each do |operator|
          UserMailer.send_new_job_email(@job, operator).deliver_later
        end
      end
      redirect_to @job, notice: @job.draft? ? "Draft saved." : "Job was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update(job_params)
      attach_uploaded_file(@job, ensure_placeholders: false)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
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
          initiator: current_user,
          history_type: "status_update"
        )
        # to appropriate user based on who changed the status
        case current_user.role
        when "operator"
          # send email to client
          UserMailer.send_job_status_change_email(@job, current_user, @job.client).deliver_later
        when "admin", "owner"
          # send email to client and operator
          UserMailer.send_job_status_change_email(@job, current_user, @job.client).deliver_later

          # have to be safe as jobs can have their status updated with no operator
          if @job.operator.present?
            UserMailer.send_job_status_change_email(@job, current_user, @job.operator).deliver_later
          end
        end
      end

      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      redirect_to @job, status: :unprocessable_content
    end
  end

  # PATCH /jobs/1/self_assign
  def self_assign
    if @job.operator_id.nil?
      old_status = @job.get_status_for_display
      @job.update!(operator: current_user, status: :assigned)
      # Automatically update job status when assigned
      JobStatusHistory.create!(
        job: @job,
        old_status: old_status,
        new_status: "assigned",
        initiator: current_user,
        new_operator: @job.operator,
        history_type: "self_assigned"
      ) if @job.saved_change_to_operator_id?
      UserMailer.send_job_accepted_email(@job).deliver_later
      redirect_to jobs_path(tab: "unassigned"), notice: "Job assigned to you.", status: :see_other
    else
      redirect_to jobs_path(tab: "unassigned"), alert: "Job is already assigned.", status: :see_other
    end
  end

  # PATCH /jobs/1/unassign
  def unassign
    old_operator = @job.operator
    old_status = @job.get_status_for_display
    if @job.update(operator: nil, status: :pending)
      JobStatusHistory.create!(
        job: @job,
        old_status: old_status,
        new_status: "pending",
        initiator: current_user,
        old_operator: old_operator,
        history_type: "job_dropped"
      )
      # since unassign is only accessed by operators it is fine to assume we can just send email to client
      UserMailer.send_job_dropped_email(@job, current_user).deliver_later
      redirect_to jobs_path(tab: "assigned"), notice: "Job unassigned from you.", status: :see_other
    else
      redirect_to jobs_path(tab: "assigned"), alert: "You can only unassign jobs assigned to you.", status: :see_other
    end
  end

  # PATCH /jobs/1/re_assign
  def re_assign
    old_status = @job.get_status_for_display
    old_operator = @job.operator
    new_operator = User.find_by(id: job_params[:operator_id].presence)
    new_status = new_operator.nil? ? :pending : :assigned
    
    if @job.update(operator: new_operator, status: new_status)
      # need to decide what type of history to create, this action can be a re-assignment, unassignment or assignment
      history_type = 
        if old_operator.nil?
          history_type = "manual_assignment"
        elsif new_operator.nil?
          history_type = "job_dropped"
        else
          history_type = "job_re_assigned"
        end

      JobStatusHistory.create!(
        job: @job,
        old_status: old_status,
        new_status: new_status.to_s,
        initiator: current_user,
        old_operator: old_operator,
        new_operator: new_operator,
        history_type: history_type
      )

      #send email based on the action performed here
      case history_type
      when "manual_assignment"
        UserMailer.send_assigned_to_job_email(@job, current_user).deliver_later
        UserMailer.send_job_accepted_email(@job).deliver_later
      when "job_dropped"
        UserMailer.send_unassigned_from_job_email(@job, old_operator, current_user).deliver_later
        UserMailer.send_job_dropped_email(@job, current_user).deliver_later
      when "job_re_assigned"
        UserMailer.send_assigned_to_job_email(@job, current_user).deliver_later
        UserMailer.send_unassigned_from_job_email(@job, old_operator, current_user).deliver_later
        UserMailer.send_operator_reassigned_email(@job, old_operator, current_user).deliver_later
      end

      notice =
        case history_type
        when "manual_assignment"
          "Operator assigned successfully."
        when "job_dropped"
          "Operator dropped successfully."
        else
          "Operator reassigned successfully."
        end

      redirect_to @job, notice: notice, status: :see_other
    else
      redirect_to @job, alert: "Failed to reassign operator.", status: :unprocessable_content
    end
  end

  # PATCH /jobs/1/complete_job
  def complete_job
    # save old status for status history record after update
    old_status = @job.get_status_for_display

    if @job.update(status: :complete)
      JobStatusHistory.create!(
        job: @job,
        old_status: old_status,
        new_status: "complete",
        initiator: current_user,
        history_type: "status_update"
      )
      case current_user.role
      when "operator"
        # send email to client
        UserMailer.send_job_completed_email(@job, @job.client).deliver_later
      when "admin", "owner"
        # send email to client and operator
        UserMailer.send_job_completed_email(@job, @job.client).deliver_later

        # have to be safe as jobs with no operator can be cancelled
        if @job.operator.present?
          UserMailer.send_job_completed_email(@job, @job.operator).deliver_later
        end
      end
      redirect_to @job, notice: "Job was successfully completed.", status: :see_other
    else
      redirect_to @job, alert: "Failed to complete job.", status: :unprocessable_content
    end
  end

  # PATCH /jobs/1/cancel_job
  def cancel_job
    # save old status for status history record after update
    old_status = @job.get_status_for_display

    if @job.draft?
      @job.destroy!
      redirect_to jobs_path(tab: "drafts"), notice: "Draft was deleted.", status: :see_other
      return
    end

    if @job.update(status: :cancelled)
      # only send email to client that their job was cancelled after it has been assigned to an operator
      JobStatusHistory.create!(
        job: @job,
        old_status: old_status,
        new_status: "cancelled",
        initiator: current_user,
        # this is the only situation i cant easily resolve in the model, cancelling pending jobs is trouble but this shouldn't affect anything
        history_type: "status_update"
      )
      case current_user.role
      when "operator"
        # send email to client
        UserMailer.send_job_cancelled_email(@job, @job.client).deliver_later
      when "admin", "owner"
        # send email to client and operator
        UserMailer.send_job_cancelled_email(@job, @job.client).deliver_later

        # have to be safe as jobs with no operator can be cancelled
        if @job.operator.present?
          UserMailer.send_job_cancelled_email(@job, @job.operator).deliver_later
        end
      end
      redirect_to @job, notice: "Job was successfully cancelled.", status: :see_other
    else
      redirect_to @job, alert: "Failed to cancel job.", status: :unprocessable_content
    end
  end

  # PATCH /jobs/1/submit_draft
  def submit_draft
    input_files = @job.image_files.reject(&:output_file?).sort_by(&:id)
    has_pdf = input_files[0]&.file_path.present?
    has_dicom = input_files[1]&.file_path.present?

    unless has_pdf && has_dicom
      redirect_to @job, alert: "Both input files (PDF and DICOM) must be uploaded before submitting."
      return
    end

    if @job.update(status: :pending)
      attach_uploaded_file(@job, ensure_placeholders: true)
      # notify all operators of the new job
      User.where(role: :operator).each do |operator|
        UserMailer.send_new_job_email(@job, operator).deliver_later
      end
      redirect_to @job, notice: "Job submitted successfully."
    else
      redirect_to @job, alert: "Failed to submit job."
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

    if @job.complete?
      redirect_to @job, alert: "Completed jobs cannot accept report uploads."
      return
    end

    unless can?(:upload_output, @job)
      redirect_to @job, alert: "You are not authorized to upload report files for this job."
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

    # send client an email that the report has been uploaded
    UserMailer.send_report_uploaded_email(@job, current_user).deliver_later

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
      when "submit_draft"
        {}
      when "re_assign"
        params.permit(:operator_id, :_method, :authenticity_token, :commit, :id)
      end
    end

    def attach_uploaded_file(job, ensure_placeholders: false)
      uploaded_files = JSON.parse(params[:uploaded_files_json].presence || "[]")
      valid_uploaded_files = uploaded_files.first(2).select do |uploaded|
        next false unless uploaded.is_a?(Hash)

        has_single = uploaded["file_id"].present? || uploaded["file_url"].present?
        multi_files = uploaded["files"]
        has_multi = multi_files.is_a?(Array) && multi_files.any? { |entry| entry.is_a?(Hash) && entry["file_id"].present? }
        has_single || has_multi
      end

      if valid_uploaded_files.blank?
        if ensure_placeholders
          existing_non_output = job.image_files.reject(&:output_file?).count
          [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
        end
        return
      end

      drive_service = build_drive_service
      destination_folder_id = ensure_drive_folder!(job, drive_service)

      valid_uploaded_files.each do |uploaded|
        slot = uploaded["slot"].to_i

        if slot == 2 && uploaded["files"].is_a?(Array)
          dicom_files = uploaded["files"].select { |entry| entry.is_a?(Hash) && entry["file_id"].present? }
          dicom_files.each { |entry| move_file_to_folder!(drive_service, entry["file_id"], destination_folder_id) }

          first = dicom_files.first
          file_id = first&.dig("file_id").presence || uploaded["file_id"].presence
          file_url = first&.dig("file_url").presence || uploaded["file_url"].presence
          file_path = file_url.presence || (file_id.present? ? "https://drive.google.com/file/d/#{file_id}/view" : nil)

          file_type = {
            slot: "2",
            file_id: file_id,
            mime_type: uploaded["file_type"].presence,
            files: dicom_files.map do |entry|
              {
                file_id: entry["file_id"],
                file_url: entry["file_url"],
                file_type: entry["file_type"],
                file_name: entry["file_name"],
                relative_path: entry["relative_path"]
              }
            end
          }.to_json
        else
          file_id = uploaded["file_id"].presence
          move_file_to_folder!(drive_service, file_id, destination_folder_id) if file_id.present?
          file_url = uploaded["file_url"].presence
          file_path = file_url.presence || (file_id.present? ? "https://drive.google.com/file/d/#{file_id}/view" : nil)
          file_type = {
            slot: (slot == 1 ? "1" : nil),
            file_id: file_id,
            mime_type: uploaded["file_type"].presence
          }.compact.to_json
        end

        image_file = job.image_files.build
        image_file.file_path = file_path
        image_file.file_type = file_type
        image_file.save!
      end

      if ensure_placeholders && uploaded_files.length < 2
        existing_non_output = job.image_files.reject(&:output_file?).count
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
      end
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to move uploaded files for job #{job.id}: #{e.message}")
    rescue JSON::ParserError
      if ensure_placeholders
        existing_non_output = job.image_files.reject(&:output_file?).count
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: "", file_type: "{}") }
      end
    end

    def ensure_drive_folder!(job, drive_service)
      return job.google_drive_folder_id if job.google_drive_folder_id.present?

      folder = drive_service.create_file(
        Google::Apis::DriveV3::File.new(
          name: "Job #{job.id} - #{job.title} [#{job.created_at.in_time_zone.strftime('%d/%m/%Y @ %H:%M:%S')}]",
          mime_type: "application/vnd.google-apps.folder",
          parents: [FilesController::FOLDER_ID]
        ),
        fields: "id",
        supports_all_drives: true
      )

      job.update_column(:google_drive_folder_id, folder.id)
      folder.id
    end

    def move_file_to_folder!(drive_service, file_id, destination_folder_id)
      metadata = drive_service.get_file(file_id, fields: "id,parents", supports_all_drives: true)
      current_parents = metadata.parents || []
      return if current_parents.include?(destination_folder_id)

      remove_parents = current_parents.join(",")
      drive_service.update_file(
        file_id,
        Google::Apis::DriveV3::File.new,
        add_parents: destination_folder_id,
        remove_parents: remove_parents.presence,
        supports_all_drives: true,
        fields: "id,parents"
      )
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
      file_ids = @job.image_files.flat_map(&:drive_file_ids).uniq
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
