# == Schema Information
#
# Table name: jobs
#
#  id          :bigint           not null, primary key
#  description :text
#  status      :integer
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  client_id   :bigint           not null
#  operator_id :bigint           not null
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
    client { nil }
    operator { nil }
    status { 1 }
    title { "MyString" }
    description { "MyString" }
    date_of_creation { "2026-03-15 14:55:52" }
  end
end
