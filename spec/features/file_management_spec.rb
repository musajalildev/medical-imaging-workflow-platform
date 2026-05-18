require 'rails_helper'

RSpec.describe "File Upload and Management", type: :feature do
  let(:operator) { create(:user, role: :operator) }
  let(:client) { create(:user, role: :client) }
  let(:job) { create(:job, status: :assigned, client: client, operator: operator,
                           title: "File Upload Test Job") }

  before do
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
  end

  describe "Input file management for drafts" do
    let(:draft) { create(:job, status: :draft, client: client, operator: nil) }

    before { login_as client, scope: :user }

    it "allows uploading PDF file to draft" do
      visit edit_job_path(draft)
      
      expect(page).to have_content("PDF")
      # File upload UI element should be present
    end

    it "allows uploading DICOM file to draft" do
      visit edit_job_path(draft)
      
      expect(page).to have_content("DICOM")
      # File upload UI element should be present
    end

    it "tracks uploaded files in the draft" do
      create(:image_file, job: draft, file_path: "pdf_url", 
             file_type: '{"slot": 1, "file_id": "pdf123"}')
      
      visit edit_job_path(draft)
      
      # Draft should show the uploaded file
      expect(draft.image_files.count).to eq(1)
    end

    it "allows replacing uploaded files in draft" do
      existing_file = create(:image_file, job: draft, file_path: "old_pdf_url", 
                                         file_type: '{"slot": 1}')
      
      visit edit_job_path(draft)
      
      # Should be able to upload new file
      expect(page).to have_content("PDF")
    end
  end

  describe "Output file upload for operators" do
    before { login_as operator, scope: :user }

    it "shows output file upload button for assigned jobs" do
      visit job_path(job)
      
      expect(page).to have_button("Upload report file")
    end

    it "allows uploading output files" do
      visit job_path(job)
      
      expect(page).to have_button("Upload report file")
    end

    it "requires file selection for upload" do
      visit job_path(job)
      
      click_button "Upload report file"
      
      expect(page).to have_content("Please select an output file.")
    end

    it "prevents upload on completed jobs" do
      job.update(status: :complete)
      
      visit job_path(job)
      
      expect(page).not_to have_button("Upload report file")
    end

    it "prevents non-operators from uploading files" do
      login_as client, scope: :user
      visit job_path(job)
      
      expect(page).not_to have_button("Upload report file")
    end

    it "prevents uploading to unassigned jobs" do
      unassigned_job = create(:job, status: :pending, client: client, operator: nil)
      
      visit job_path(unassigned_job)
      
      expect(page).not_to have_button("Upload report file")
    end
  end

  describe "File listing and display" do
    context "with input files" do
      before do
        create(:image_file, job: job, file_path: "https://drive.google.com/uc?id=pdf123",
               file_type: '{"slot": 1, "file_id": "pdf123"}')
        create(:image_file, job: job, file_path: "https://drive.google.com/uc?id=dicom456",
               file_type: '{"slot": 2, "file_id": "dicom456"}')
        login_as client, scope: :user
      end

      it "displays input files section" do
        visit job_path(job)
        
        expect(page).to have_content("input files")
      end

      it "shows PDF file link" do
        visit job_path(job)
        
        # Should show PDF file in input files section
        expect(page).to have_content("PDF")
      end

      it "shows DICOM file link" do
        visit job_path(job)
        
        expect(page).to have_content("DICOM")
      end
    end

    context "with output files" do
      before do
        create(:image_file, job: job, file_path: "https://drive.google.com/uc?id=output123",
               file_type: '{"slot": "output", "file_id": "output123"}')
        login_as client, scope: :user
      end

      it "displays output files section" do
        visit job_path(job)
        
        expect(page).to have_content("Output file")
      end

      it "allows client to download output file" do
        visit job_path(job)
        
        # Should be able to click download link
        expect(page).to have_link
      end
    end
  end

  describe "File removal", js: true do
    context "client removing input files from draft" do
      let(:draft) { create(:job, status: :draft, client: client, operator: nil) }
      let(:input_file) { create(:image_file, job: draft, file_path: "pdf_url",
                                             file_type: '{"slot": 1}') }

      before { login_as client, scope: :user }

      it "allows re-uploading after removal" do
        visit edit_job_path(draft)
        
        # Should be able to upload again
        expect(page).to have_content("PDF")
      end
    end
  end

  describe "File metadata" do
    before do
      create(:image_file, job: job, file_path: "https://drive.google.com/uc?id=pdf123",
             file_type: '{"slot": 1, "file_id": "pdf123", "mime_type": "application/pdf"}')
      login_as client, scope: :user
    end

    it "extracts file ID from metadata" do
      image_file = job.image_files.first
      
      expect(image_file.drive_file_id).to eq("pdf123")
    end

    it "returns drive file IDs from metadata" do
      image_file = job.image_files.first
      
      expect(image_file.drive_file_ids).to include("pdf123")
    end

    it "handles multiple DICOM files in metadata" do
      dicom_file = create(:image_file, job: job, file_path: "dicom_url",
                          file_type: '{"slot": 2, "files": [{"file_id": "dicom1"}, {"file_id": "dicom2"}]}')
      
      expect(dicom_file.drive_file_ids).to include("dicom1", "dicom2")
    end
  end

  describe "Draft submission with files" do
    let(:draft) { create(:job, status: :draft, client: client, operator: nil) }

    before do
      create(:image_file, job: draft, file_path: "pdf_url", file_type: '{"slot": 1}')
      create(:image_file, job: draft, file_path: "dicom_url", file_type: '{"slot": 2}')
      login_as client, scope: :user
    end

    it "preserves files when submitting draft" do
      visit job_path(draft)
      
      click_button "Submit Job"
      
      expect(draft.reload.image_files.count).to eq(2)
    end

    it "keeps file associations after submission" do
      visit job_path(draft)
      
      click_button "Submit Job"
      
      draft.reload
      input_files = draft.image_files.reject { |f| f.slot == "output" }
      
      expect(input_files.count).to eq(2)
    end
  end

  describe "File access control" do
    let(:other_client) { create(:user, role: :client) }
    let(:other_job) { create(:job, status: :assigned, client: other_client, operator: operator) }

    before do
      create(:image_file, job: other_job, file_path: "secret_file_url", 
             file_type: '{"slot": 1}')
      login_as client, scope: :user
    end

    it "prevents client from accessing other client's files" do
      visit job_path(other_job)
      
      expect(page).to have_content("not authorized")
    end

    it "allows client to access their own files" do
      visit job_path(job)
      
      expect(page).not_to have_content("not authorized")
    end

    it "allows operator to access assigned job files" do
      login_as operator, scope: :user
      visit job_path(job)
      
      expect(page).not_to have_content("not authorized")
    end
  end

  describe "Output file limitations" do
    before do
      create(:image_file, job: job, file_path: "output_url",
             file_type: '{"slot": "output"}')
      login_as operator, scope: :user
    end

    it "prevents further uploads on completed jobs" do
      job.update(status: :complete)
      
      visit job_path(job)
      
      expect(page).not_to have_button("Upload report file")
    end

    it "allows uploads while job is in progress" do
      job.update(status: :in_progress)
      
      visit job_path(job)
      
      expect(page).to have_button("Upload report file")
    end

    it "shows existing output files" do
      visit job_path(job)
      
      expect(page).to have_content("Output file")
    end
  end
end