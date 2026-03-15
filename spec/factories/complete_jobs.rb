# == Schema Information
#
# Table name: complete_jobs
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  job_id     :bigint           not null
#
# Indexes
#
#  index_complete_jobs_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
FactoryBot.define do
  factory :complete_job do
    job { nil }
  end
end
