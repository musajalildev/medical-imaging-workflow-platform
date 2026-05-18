# == Schema Information
#
# Table name: jobs
#
#  id                     :bigint           not null, primary key
#  custom_status          :string
#  description            :text
#  status                 :integer          not null
#  title                  :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  client_id              :bigint           not null
#  google_drive_folder_id :string
#  operator_id            :bigint
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
    client { association :user, role: :client }
    operator { association :user, role: :operator }
    status { :pending }
    title { "Test Job" }
    description { "Test Description" }
  end
end
