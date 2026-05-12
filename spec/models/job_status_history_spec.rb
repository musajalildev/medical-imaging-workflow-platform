# == Schema Information
#
# Table name: job_status_histories
#
#  id                            :bigint           not null, primary key
#  history_type                  :integer          default("status_update"), not null
#  new_status                    :string           not null
#  old_status                    :string           not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  initiator_id                  :bigint           not null
#  job_id                        :bigint           not null
#  new_operator_id               :bigint
#  old_operator_id               :bigint
#  operator_at_time_of_update_id :bigint           not null
#
# Indexes
#
#  index_job_status_histories_on_initiator_id                   (initiator_id)
#  index_job_status_histories_on_job_id                         (job_id)
#  index_job_status_histories_on_new_operator_id                (new_operator_id)
#  index_job_status_histories_on_old_operator_id                (old_operator_id)
#  index_job_status_histories_on_operator_at_time_of_update_id  (operator_at_time_of_update_id)
#
# Foreign Keys
#
#  fk_rails_...  (initiator_id => users.id)
#  fk_rails_...  (job_id => jobs.id)
#  fk_rails_...  (new_operator_id => users.id)
#  fk_rails_...  (old_operator_id => users.id)
#  fk_rails_...  (operator_at_time_of_update_id => users.id)
#
require 'rails_helper'

RSpec.describe JobStatusHistory, type: :model do

  describe '#formatted_history' do
    let(:operator) { User.create!(email: "operator@example.com") }
    let(:client) { User.create!(email: "client@example.com") }
    let(:job) { Job.create!(client: client, operator: operator, title: "Test Job", description: "This is a test job.", status: :pending) }
    let(:history) { JobStatusHistory.create!(job: job, old_status: :pending, new_status: :assigned, initiator: operator) }

    it 'returns a formatted string with initiator email, old status, new status, and timestamp' do
      expect(history.formatted_history).to eq("operator@example.com changed status from Pending to Assigned on #{history.created_at.strftime("%Y/%m/%d, at %H:%M")}")
    end

    it 'humanizes the old and new status' do
      in_progress_history = JobStatusHistory.create!(job: job, old_status: :assigned, new_status: :in_progress, initiator: operator)
      expect(in_progress_history.formatted_history).to include("In progress")
    end

    it 'includes the correct timestamp' do
      time = Time.new(2024, 2, 12, 9, 5, 3)
      allow(history).to receive(:created_at).and_return(time)
      expect(history.formatted_history).to include("2024/02/12, at 09:05")
    end

    it "handles different initiators correctly" do
      another_operator = User.create!(email: "another_operator@example.com")
      another_history = JobStatusHistory.create!(job: job, old_status: :pending, new_status: :assigned, initiator: another_operator)
      expect(another_history.formatted_history).to include("another_operator@example.com")
    end

    it "handles multiple status changes correctly" do
      second_history = JobStatusHistory.create!(job: job, old_status: :assigned, new_status: :in_progress, initiator: operator)
      expect(second_history.formatted_history).to include("Assigned to In progress")
    end

    it "handles edge cases with status changes" do
      edge_history = JobStatusHistory.create!(job: job, old_status: :failed, new_status: :pending, initiator: operator)
      expect(edge_history.formatted_history).to include("Failed to Pending")
    end
  end
end
