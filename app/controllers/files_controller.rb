require "google/apis/drive_v3"
require "googleauth"
require "stringio"
class FilesController < ApplicationController
  FOLDER_ID = "0AMU1EVlpjzbkUk9PVA"
  MAX_FILE_SIZE_BYTES = 1_073_741_824 # 1 GB

  skip_before_action :dev_auto_login, only: :upload
  skip_before_action :authenticate_user!, only: :upload
  skip_forgery_protection only: :upload

  def upload
    file = params.require(:file)
    slot = params[:slot].to_s
    validate_input_file!(file, slot)

    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.client_options.application_name = "Rails Drive Upload"

    service_account_path = Rails.root.join("service_account.json")
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(service_account_path),
      scope: [Google::Apis::DriveV3::AUTH_DRIVE]
    )
    credentials.fetch_access_token!
    drive_service.authorization = credentials

    metadata = Google::Apis::DriveV3::File.new(
      name: file.original_filename,
      parents: [FOLDER_ID]
    )

    uploaded_file = drive_service.create_file(
      metadata,
      upload_source: file.tempfile,
      content_type: file.content_type.presence || "application/octet-stream",
      fields: "id, webViewLink, webContentLink",
      supports_all_drives: true
    )

    file_url = uploaded_file.web_view_link.presence || uploaded_file.web_content_link.presence || "https://drive.google.com/file/d/#{uploaded_file.id}/view"

    render json: {
      success: true,
      file_id: uploaded_file.id,
      file_url: file_url
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def download
    file_id = params.require(:file_id)

    drive_service = Google::Apis::DriveV3::DriveService.new
    drive_service.client_options.application_name = "Rails Drive Upload"

    service_account_path = Rails.root.join("service_account.json")
    credentials = Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(service_account_path),
      scope: [Google::Apis::DriveV3::AUTH_DRIVE]
    )
    credentials.fetch_access_token!
    drive_service.authorization = credentials

    metadata = drive_service.get_file(file_id, fields: "name,mimeType", supports_all_drives: true)
    io = StringIO.new
    drive_service.get_file(file_id, download_dest: io, supports_all_drives: true)
    io.rewind

    send_data io.read,
              filename: metadata.name.presence || "downloaded_file",
              type: metadata.mime_type.presence || "application/octet-stream",
              disposition: "attachment"
  rescue StandardError => e
    render plain: "Download failed: #{e.message}", status: :internal_server_error
  end

  def remove
    image_file = ImageFile.find(params.require(:image_file_id))
    file_id = image_file.drive_file_id

    if file_id.present?
      drive_service = Google::Apis::DriveV3::DriveService.new
      drive_service.client_options.application_name = "Rails Drive Upload"

      service_account_path = Rails.root.join("service_account.json")
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(service_account_path),
        scope: [Google::Apis::DriveV3::AUTH_DRIVE]
      )
      credentials.fetch_access_token!
      drive_service.authorization = credentials

      metadata = drive_service.get_file(
        file_id,
        fields: 'id,name,driveId,parents,capabilities(canDelete,canTrash)',
        supports_all_drives: true
      )

      if metadata.capabilities&.can_delete
        drive_service.delete_file(file_id, supports_all_drives: true)
      elsif metadata.capabilities&.can_trash
        drive_service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new(trashed: true),
          supports_all_drives: true,
          fields: 'id'
        )
      elsif metadata.parents&.include?(FOLDER_ID)
        drive_service.update_file(
          file_id,
          Google::Apis::DriveV3::File.new,
          remove_parents: FOLDER_ID,
          supports_all_drives: true,
          fields: 'id'
        )
      else
        raise "Google Drive does not allow this service account to delete, trash, or remove the file from the folder."
      end
    end

    image_file.update!(file_path: nil, file_type: nil)
    redirect_back fallback_location: jobs_path, notice: "File deleted."
  rescue Google::Apis::ClientError => e
    redirect_back fallback_location: jobs_path, alert: "File delete failed. The service account likely lacks delete permission for this Shared Drive file: #{e.message}"
  rescue StandardError => e
    redirect_back fallback_location: jobs_path, alert: "File delete failed: #{e.message}"
  end

  private

  def validate_input_file!(file, slot)
    raise ArgumentError, "Please select a file to upload." if file.blank?

    if file.size.to_i > MAX_FILE_SIZE_BYTES
      raise ArgumentError, "File exceeds 1 GB size limit."
    end

    extension = File.extname(file.original_filename.to_s).downcase
    case slot
    when "1"
      raise ArgumentError, "PDF file must have .pdf extension." unless extension == ".pdf"
    when "2"
      raise ArgumentError, "DICOM file must have .dcm extension." unless extension == ".dcm"
    else
      raise ArgumentError, "Invalid upload slot."
    end
  end
end
