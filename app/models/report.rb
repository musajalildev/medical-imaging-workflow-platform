# == Schema Information
#
# Table name: reports
#
#  id         :bigint           not null, primary key
#  file_path  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  job_id     :bigint           not null
#
# Indexes
#
#  index_reports_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
class Report < ApplicationRecord
  belongs_to :job
end
