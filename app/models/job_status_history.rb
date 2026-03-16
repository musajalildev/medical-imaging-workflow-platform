# == Schema Information
#
# Table name: job_status_histories
#
#  id           :bigint           not null, primary key
#  new_status   :integer
#  old_status   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  initiator_id :bigint           not null
#  job_id       :bigint           not null
#
# Indexes
#
#  index_job_status_histories_on_initiator_id  (initiator_id)
#  index_job_status_histories_on_job_id        (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (initiator_id => users.id)
#  fk_rails_...  (job_id => jobs.id)
#
class JobStatusHistory < ApplicationRecord
  belongs_to :job
  belongs_to :initiator

  enum :old_status, Job::STATUSES, prefix: :old
  enum :new_status, Job::STATUSES, prefix :new
end
