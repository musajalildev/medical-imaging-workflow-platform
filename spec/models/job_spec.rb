# spec/models/job_spec.rb
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
require "rails_helper"

RSpec.describe Job, type: :model do
  let(:client) { create(:user, role: :client) }

  describe "validations" do
    it "is valid with a title and description" do
      job = build(:job, client: client, title: "Test Job", description: "Test Description")
      expect(job).to be_valid
    end

    it "is invalid without a title" do
      job = build(:job, client: client, title: nil, description: "Test Description")
      expect(job).not_to be_valid
    end

    it "is invalid without a description unless it is a draft" do
      job = build(:job, client: client, title: "Test Job", description: nil, status: :pending)
      expect(job).not_to be_valid
    end

    it "is valid without a description when draft" do
      job = build(:job, client: client, title: "Draft Job", description: nil, status: :draft)
      expect(job).to be_valid
    end
  end

  describe "default status" do
    it "defaults to pending" do
      job = build(:job, client: client, title: "Test Job", description: "Test Description", status: nil)
      job.valid?
      expect(job.status).to eq("pending")
    end
  end

  describe "#get_status_for_display" do
    it "returns the custom status when status is custom" do
      job = build(:job, client: client, title: "Test Job", description: "Test Description", status: :custom, custom_status: "Waiting on client")
      expect(job.get_status_for_display).to eq("Waiting on client")
    end

    it "returns a humanized status for normal statuses" do
      job = build(:job, client: client, title: "Test Job", description: "Test Description", status: :in_progress)
      expect(job.get_status_for_display).to eq("In progress")
    end
  end
end
