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
require 'rails_helper'

RSpec.describe JobStatusHistory, type: :model do

  describe '#formatted_history' do
    let(:operator) { User.create!(email: "operator@example.com", role: :operator) }
    let(:client) { User.create!(email: "client@example.com", role: :client) }
    let(:admin) { User.create!(email: "admin@example.com", role: :admin) }

    let(:job) do
      Job.create!(
        client: client,
        operator: operator,
        title: "Test Job",
        description: "This is a test job.",
        status: :pending
      )
    end

    let(:history) do
      JobStatusHistory.create!(
        job: job,
        old_status: :pending,
        new_status: :assigned,
        initiator: operator,
        history_type: :status_update
      )
    end

    it 'returns a formatted string with initiator email, old status, new status, and timestamp' do
      expect(history.formatted_history).to eq(
        "Operator operator@example.com changed status from Pending to Assigned on #{history.created_at.strftime("%Y/%m/%d, at %H:%M")}"
      )
    end

    it 'humanizes the old and new status' do
      in_progress_history = JobStatusHistory.create!(
        job: job,
        old_status: :assigned,
        new_status: :in_progress,
        initiator: operator,
        history_type: :status_update
      )

      expect(in_progress_history.formatted_history).to include("In progress")
    end

    it 'includes the correct timestamp' do
      time = Time.new(2024, 2, 12, 9, 5, 3)
      allow(history).to receive(:created_at).and_return(time)

      expect(history.formatted_history).to include("2024/02/12, at 09:05")
    end

    it "handles different initiators correctly" do
      another_operator = User.create!(
        email: "another_operator@example.com",
        role: :operator
      )

      another_history = JobStatusHistory.create!(
        job: job,
        old_status: :pending,
        new_status: :assigned,
        initiator: another_operator,
        history_type: :status_update
      )

      expect(another_history.formatted_history).to include("another_operator@example.com")
    end

    it "handles multiple status changes correctly" do
      second_history = JobStatusHistory.create!(
        job: job,
        old_status: :assigned,
        new_status: :in_progress,
        initiator: operator,
        history_type: :status_update
      )

      expect(second_history.formatted_history).to include("from Assigned to In progress")
    end

    it "handles edge cases with status changes" do
      edge_history = JobStatusHistory.create!(
        job: job,
        old_status: :failed,
        new_status: :pending,
        initiator: operator,
        history_type: :status_update
      )

      expect(edge_history.formatted_history).to include("from Failed to Pending")
    end

    it "formats dropped jobs correctly" do
      dropped_history = JobStatusHistory.create!(
        job: job,
        old_status: :assigned,
        new_status: :pending,
        initiator: operator,
        old_operator: operator,
        history_type: :job_dropped
      )

      expect(dropped_history.formatted_history).to include("dropped this job")
    end

    it "formats reassigned jobs correctly" do
      new_operator = User.create!(
        email: "new_operator@example.com",
        role: :operator
      )

      reassigned_history = JobStatusHistory.create!(
        job: job,
        old_status: :assigned,
        new_status: :assigned,
        initiator: admin,
        old_operator: operator,
        new_operator: new_operator,
        history_type: :job_re_assigned
      )

      expect(reassigned_history.formatted_history).to include(
        "from operator@example.com to new_operator@example.com"
      )
    end

    it "formats manual assignments correctly" do
      assignment_history = JobStatusHistory.create!(
        job: job,
        old_status: :pending,
        new_status: :assigned,
        initiator: admin,
        new_operator: operator,
        history_type: :manual_assignment
      )

      expect(assignment_history.formatted_history).to include(
        "assigned this job to operator@example.com"
      )
    end
  end
end
