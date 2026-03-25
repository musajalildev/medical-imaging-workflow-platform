require "google/apis/drive_v3"
require "googleauth"

class JobsController < ApplicationController
  MAX_FILE_SIZE_BYTES = 1_073_741_824 # 1 GB
  before_action :set_job, only: %i[ show edit update destroy upload_output ]
  before_action :check_client_role, only: %i[ new create edit update ]

  # GET /jobs
  def index
    @jobs = Job.all
  end

  # GET /jobs/1
  def show
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

    # Only allow a list of trusted parameters through.
    def job_params
      params.expect(job: [ :client_id, :operator_id, :status, :title, :description ])
    end

    def attach_uploaded_file(job, ensure_placeholders: false)
      uploaded_files = JSON.parse(params[:uploaded_files_json].presence || "[]")
      if uploaded_files.blank?
        if ensure_placeholders
          existing_non_output = job.image_files.reject(&:output_file?).count
          [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: nil, file_type: nil) }
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
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: nil, file_type: nil) }
      end
    rescue JSON::ParserError
      if ensure_placeholders
        existing_non_output = job.image_files.reject(&:output_file?).count
        [2 - existing_non_output, 0].max.times { job.image_files.create!(file_path: nil, file_type: nil) }
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
