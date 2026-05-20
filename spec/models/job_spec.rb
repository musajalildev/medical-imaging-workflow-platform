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

  describe "#get_title_for_display" do
    it "returns a normal title" do
      job = build(:job, client: client, title: "Test Job")
      expect(job.get_title_for_display(client)).to eq("Test Job")
    end

    it "returns a job queued for deletion when user is admin and job is closed" do
      job = build(:job, client: client, title: "Test Job", status: :cancelled)
      admin = create(:user, role: :admin)

      expect(job.get_title_for_display(admin)).to eq("[Queued for Deletion] Test Job")
    end
  end

  describe "#assigned" do
    it "returns true when an operator is present" do
      operator = create(:user, role: :operator)
      job = build(:job, operator: operator)

      expect(job.assigned?).to eq(true)
    end

    it "returns false when no operator is present" do
      job = build(:job, operator: nil)

      expect(job.assigned?).to eq(false)
    end
  end

  describe '#create_google_drive_folder' do
    # Mock Google API objects
    let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
    let(:credentials)   { instance_double(Google::Auth::ServiceAccountCredentials) }
    let(:created_folder) { double(id: "test_folder_id") }

    before do
      # Stub DriveService instantiation
      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive_service)
      allow(drive_service).to receive(:client_options).and_return(double(application_name: nil, "application_name=" => nil))

      # Stub credentials
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(credentials)
      allow(credentials).to receive(:fetch_access_token!)
      allow(drive_service).to receive(:authorization=)

      # Stub file creation
      allow(Google::Apis::DriveV3::File).to receive(:new).and_return(double)
      allow(drive_service).to receive(:create_file).and_return(created_folder)

      # Prevent real file reads
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(Rails.root.join("service_account.json")).and_return(double)
    end

    context 'when google_drive_folder_id is already present' do
      let(:job_with_folder) { create(:job, google_drive_folder_id: "existing_id") }

      it 'returns early and does not call the Drive API' do
        expect(drive_service).not_to receive(:create_file)
        job_with_folder = create(:job, google_drive_folder_id: "existing_id")
      end
    end

    context 'when google_drive_folder_id is absent' do
      it 'creates a folder and saves the ID' do
        job = create(:job, google_drive_folder_id: nil)
        expect(job.reload.google_drive_folder_id).to eq("test_folder_id")
      end

      it 'sets the folder name with job details' do
        job_title = "some title"
        job_id = 4

        expect(Google::Apis::DriveV3::File).to receive(:new).with(
          hash_including(
            name: match(/Job #{job_id} - #{job_title}/),
            mime_type: "application/vnd.google-apps.folder"
          )
        )
        job = create(:job, google_drive_folder_id: nil, title: job_title, id: job_id)
      end
    end

    context 'when the Drive API raises an error' do
      before do
        allow(drive_service).to receive(:create_file).and_raise(StandardError, "API error")
      end

      it 'does not raise an error' do
        expect { job = create(:job, google_drive_folder_id: nil) }.not_to raise_error
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(match(/Failed to create Google Drive folder/))
        job = create(:job, google_drive_folder_id: nil)
      end

      it 'does not update the folder ID' do
        job = create(:job, google_drive_folder_id: nil)
        expect(job.reload.google_drive_folder_id).to be_nil
      end
    end
  end
end
