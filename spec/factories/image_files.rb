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
FactoryBot.define do
  factory :image_file do
    job { nil }
    file_path { "MyString" }
    file_type { "MyString" }
  end
end
