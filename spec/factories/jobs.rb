# == Schema Information
#
# Table name: jobs
#
#  id         :bigint           not null, primary key
#  status     :string
#  title      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_jobs_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
FactoryBot.define do
  factory :job do
    title { "MyString" }
    status { "MyString" }
    user { nil }
  end
end
