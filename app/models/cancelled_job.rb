# == Schema Information
#
# Table name: cancelled_jobs
#
#  id            :bigint           not null, primary key
#  cancel_reason :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  job_id        :bigint           not null
#
# Indexes
#
#  index_cancelled_jobs_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
class CancelledJob < ApplicationRecord
  belongs_to :job
end
