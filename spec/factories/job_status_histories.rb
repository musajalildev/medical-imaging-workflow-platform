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
FactoryBot.define do
  factory :job_status_history do
    job { nil }
    old_status { 1 }
    new_status { 1 }
    initiator { nil }
  end
end
