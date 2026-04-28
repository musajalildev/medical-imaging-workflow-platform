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
require 'rails_helper'

RSpec.describe Job, type: :model do
  describe '#status_histories' do
    let(:client) { User.create!(email: "client@example.com") }
    let(:operator) { User.create!(email: "operator@example.com") }
    let(:job) { Job.create!(client: client, operator: operator, title: "Test Job", description: "This is a test job.", status: :pending) }

    it 'returns the correct status histories' do
      history1 = JobStatusHistory.create!(job: job, old_status: :pending, new_status: :assigned, initiator: operator)
      history2 = JobStatusHistory.create!(job: job, old_status: :assigned, new_status: :in_progress, initiator: operator)

      expect(job.status_histories).to include(history1)
      expect(job.status_histories).to include(history2)
    end

    it 'returns status histories in the correct order' do
      history1 = JobStatusHistory.create!(job: job, old_status: :pending, new_status: :assigned, initiator: operator, created_at: 1.day.ago)
      history2 = JobStatusHistory.create!(job: job, old_status: :assigned, new_status: :in_progress, initiator: operator, created_at: Time.now)

      expect(job.status_histories.first).to eq(history2)
      expect(job.status_histories.second).to eq(history1)
    end

    it 'returns an empty array if there are no status histories' do
      expect(job.status_histories).to be_empty
    end

    it 'only returns status histories for the correct job' do
      other_job = Job.create!(client: client, operator: operator, title: "Other Job", description: "This is another job.", status: :pending)
      history1 = JobStatusHistory.create!(job: job, old_status: :pending, new_status: :assigned, initiator: operator)
      history2 = JobStatusHistory.create!(job: other_job, old_status: :pending, new_status: :assigned, initiator: operator)

      expect(job.status_histories).to include(history1)
      expect(job.status_histories).not_to include(history2)
    end
  end

  let(:client) { create(:user) }

  describe 'creation' do
    it 'creates a valid job' do
      job = Job.create!(title: 'Test Job', status: :pending, client: client)
      expect(job).to be_persisted
    end


    it 'is invalid without a client' do
      job = Job.new(title: 'Test Job', status: :pending)
      expect(job).not_to be_valid
    end
  end

  describe 'updating' do
    let(:job) { Job.create!(title: 'Test Job', status: :pending, client: client) }

    it 'updates the title' do
      job.update!(title: 'Updated Title')
      expect(job.reload.title).to eq('Updated Title')
    end

    it 'updates the status' do
      job.update!(status: :assigned)
      expect(job.reload.status).to eq('assigned')
    end
  end

  describe 'deletion' do
    let(:job) { Job.create!(title: 'Test Job', status: :pending, client: client) }

    it 'destroys the job' do
      job.destroy
      expect(Job.find_by(id: job.id)).to be_nil
    end
  end
end
