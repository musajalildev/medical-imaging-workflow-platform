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
class Job < ApplicationRecord
  belongs_to :client
  belongs_to :operator

  STATUSES = { :pending, :assigned, :in_progress, :complete, :failed }

  enum :status, STATUSES
end
