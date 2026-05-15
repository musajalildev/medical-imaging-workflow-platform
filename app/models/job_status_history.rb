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
class JobStatusHistory < ApplicationRecord
  belongs_to :job
  belongs_to :initiator, class_name: 'User'
  belongs_to :new_operator, class_name: 'User', optional: true
  belongs_to :old_operator, class_name: 'User', optional: true  

  validates :old_operator, presence: true, if: :needs_old_operator?
  validates :new_operator, presence: true, if: :needs_new_operator?

  HISTORY_TYPES = [ :status_update, :job_dropped, :job_re_assigned, :self_assigned, :manual_assignment ]
  enum :history_type, HISTORY_TYPES

  # get formatted status history for display
  def formatted_history
    case history_type
    when "status_update"
      "#{user_dialogue} #{initiator.email} changed status from #{old_status.humanize} to #{new_status.humanize} on #{formatted_timestamp}"
    
    when "job_dropped"
      "#{user_dialogue} #{initiator.email} dropped this job#{admin_dropped_job}, reverting its status from #{old_status.humanize} to #{new_status.humanize} on #{formatted_timestamp}"
    
    when "job_re_assigned"
      "#{user_dialogue} #{initiator.email} re-assigned the operator for this job, from #{old_operator&.email || "none"} to #{new_operator&.email || "none"}, #{status_change_on_reassignment_dialogue} on #{formatted_timestamp}"
    
    when "self_assigned"
      "#{user_dialogue} #{initiator.email} self assigned this job, updating the status from #{old_status.humanize} to #{new_status.humanize} on #{formatted_timestamp}"
    
    when "manual_assignment"
      "#{user_dialogue} #{initiator.email} assigned this job to #{new_operator&.email}, changing it's status from #{old_status.humanize} to #{new_status.humanize} on #{formatted_timestamp}"
    end
  end

  private
    def user_dialogue
      case initiator.role
      when "client"
        "The Client"
      when "operator"
        "Operator"
      else
        "System administrator"
      end
    end

    def formatted_timestamp
      created_at.strftime("%Y/%m/%d, at %H:%M")
    end

    def admin_dropped_job
      if user_dialogue == "System administrator"
        " from #{old_operator&.email}"
      else
        ""
      end
    end

    def status_change_on_reassignment_dialogue
      if old_status.humanize == new_status.humanize
        "The status remained as #{old_status}"
      else
        "reverting the status from #{old_status.humanize} to #{new_status.humanize}"
      end
    end

    def needs_new_operator?
      self_assigned? || manual_assignment?
    end

    def needs_old_operator?
      job_dropped?
    end
end
