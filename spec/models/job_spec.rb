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
