# == Schema Information
#
# Table name: image_files
#
#  id         :bigint           not null, primary key
#  file_path  :string
#  file_type  :string
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
end
