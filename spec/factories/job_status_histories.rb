# == Schema Information
#
# Table name: job_status_histories
#
#  id              :bigint           not null, primary key
#  history_type    :integer          default("status_update"), not null
#  new_status      :string           not null
#  old_status      :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  initiator_id    :bigint           not null
#  job_id          :bigint           not null
#  new_operator_id :bigint
#  old_operator_id :bigint
#
# Indexes
#
#  index_job_status_histories_on_initiator_id     (initiator_id)
#  index_job_status_histories_on_job_id           (job_id)
#  index_job_status_histories_on_new_operator_id  (new_operator_id)
#  index_job_status_histories_on_old_operator_id  (old_operator_id)
#
# Foreign Keys
#
#  fk_rails_...  (initiator_id => users.id)
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (new_operator_id => users.id)
#  fk_rails_...  (old_operator_id => users.id)
#
FactoryBot.define do
  factory :job_status_history do
    association :job
    old_status { 0 }
    new_status { job.status }
    initiator { job.operator || job.client }
  end
end
