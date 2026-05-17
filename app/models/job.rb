# == Schema Information
#
# Table name: jobs
#
#  id            :bigint           not null, primary key
#  custom_status :string
#  description   :text
#  status        :integer          not null
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  client_id     :bigint           not null
#  operator_id   :bigint
#
# Indexes
#
#  index_jobs_on_client_id    (client_id)
#  index_jobs_on_operator_id  (operator_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => users.id)
#  fk_rails_...  (operator_id => users.id)
#
class Job < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :operator, class_name: "User", optional: true
  has_many :image_files, dependent: :destroy

  before_validation :set_default_status
  after_create :create_google_drive_folder

  validates :title, presence: true
  validates :description, presence: true, unless: :draft?

  STATUSES = [ :pending, :assigned, :in_progress, :custom, :complete, :cancelled, :draft ]
  enum :status, STATUSES

  # get all the status history for this job, ordered by most recent first
  def status_histories
    JobStatusHistory.where(job: self).order(created_at: :desc)
  end

  # get status for display, using custom status if status is set to custom
  def get_status_for_display
    if status == "custom"
      custom_status
    else
      status.to_s.humanize
    end
  end

  private

  def set_default_status
    self.status = :pending if status.blank?
  end

  def create_google_drive_folder
    return if google_drive_folder_id.present?
    
    require "google/apis/drive_v3"
    require "googleauth"
    
    begin
      drive_service = Google::Apis::DriveV3::DriveService.new
      drive_service.client_options.application_name = "Rails Drive Upload"
      
      service_account_path = Rails.root.join("service_account.json")
      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(service_account_path),
        scope: [Google::Apis::DriveV3::AUTH_DRIVE]
      )
      credentials.fetch_access_token!
      drive_service.authorization = credentials
      
      # Create folder with job title, ID, and creation timestamp for uniqueness
      folder_name = "Job #{id} - #{title} [#{created_at.in_time_zone.strftime('%d/%m/%Y @ %H:%M:%S')}]"
      folder_metadata = Google::Apis::DriveV3::File.new(
        name: folder_name,
        mime_type: "application/vnd.google-apps.folder",
        parents: ["0AMU1EVlpjzbkUk9PVA"]  # Main shared folder
      )
      
      created_folder = drive_service.create_file(
        folder_metadata,
        fields: "id",
        supports_all_drives: true
      )
      
      update_column(:google_drive_folder_id, created_folder.id)
    rescue StandardError => e
      Rails.logger.error("Failed to create Google Drive folder for job #{id}: #{e.message}")
      # Don't fail job creation if folder creation fails
    end
  end
end
