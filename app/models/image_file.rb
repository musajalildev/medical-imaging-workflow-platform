# == Schema Information
#
# Table name: image_files
#
#  id         :bigint           not null, primary key
#  file_path  :string           not null
#  file_type  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  job_id     :bigint           not null
#
# Indexes
#
#  index_image_files_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
class ImageFile < ApplicationRecord
  belongs_to :job

  def drive_metadata
    JSON.parse(file_type)
  rescue JSON::ParserError, TypeError
    {}
  end

  def drive_file_id
    drive_metadata["file_id"].presence || file_path.to_s[/\/d\/([^\/?]+)/, 1] || file_path.to_s[/[?&]id=([^&]+)/, 1]
  end

  def mime_type_value
    drive_metadata["mime_type"].presence
  end
end
