# == Schema Information
#
# Table name: job_status_histories
#
#  id           :bigint           not null, primary key
#  new_status   :string           not null
#  old_status   :string           not null
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
  belongs_to :initiator, class_name: 'User'

  # get formatted status history for display
  def formatted_history
    "#{initiator.email} changed status from #{old_status.humanize} to #{new_status.humanize} on #{created_at.strftime("%Y/%m/%d, at %H:%M")}"
  end
end
