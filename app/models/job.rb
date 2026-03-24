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
class Job < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :operator, class_name: "User"
  has_many :image_files, dependent: :destroy
  STATUSES = [ :pending, :assigned, :in_progress, :complete, :failed ]
  
  enum :status, STATUSES
end
