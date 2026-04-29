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
  belongs_to :operator, class_name: "User", optional: true
  has_many :image_files, dependent: :destroy

  before_validation :set_default_status

  validates :title, presence: true
  validates :description, presence: true

  STATUSES = [ :pending, :assigned, :in_progress, :custom, :complete, :cancelled ]
  enum :status, STATUSES

  # get all the status history for this job, ordered by most recent first
  def status_histories
    JobStatusHistory.where(job: self).order(created_at: :desc)
  end

  # get status for display, using custom status if status is set to custom
  def get_status_for_display
    if status == "custom"
      custom_status
    else
      status.to_s.humanize
    end
  end

  private

  def set_default_status
    self.status = :pending if status.blank?
  end
end
