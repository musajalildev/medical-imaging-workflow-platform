require "google/apis/drive_v3"
require "googleauth"
class FilesController < ApplicationController
  FOLDER_ID = "0AMU1EVlpjzbkUk9PVA"

  skip_before_action :dev_auto_login, only: :upload
  skip_before_action :authenticate_user!, only: :upload
  skip_forgery_protection only: :upload

  def upload
    file = params.require(:file)

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
      fields: "id",
      supports_all_drives: true
    )

    render json: { success: true, file_id: uploaded_file.id }
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
