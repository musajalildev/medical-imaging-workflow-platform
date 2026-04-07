# == Schema Information
#
# Table name: jobs
#
#  id            :bigint           not null, primary key
#  custom_status :string
#  description   :text
#  status        :integer          not null
#  title         :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  client_id     :bigint           not null
#  operator_id   :bigint
#
# Indexes
#
#  index_jobs_on_client_id    (client_id)
#  index_jobs_on_operator_id  (operator_id)
#
# Foreign Keys
#
#  fk_rails_...  (client_id => users.id)
#  fk_rails_...  (operator_id => users.id)
#
FactoryBot.define do
  factory :job do
    association :client, factory: [:user, :client]
    association :operator, factory: [:user, :operator]
    title { "Test Job" }
    description { "This is a test job." }
    status { :assigned }
  end
end
