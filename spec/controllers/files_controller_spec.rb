require "rails_helper"

RSpec.describe FilesController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)

    # Safety guard: if any example accidentally touches the real Drive client,
    # the spec will fail instead of creating anything in Google Drive.
    allow(Google::Apis::DriveV3::DriveService).to receive(:new)
      .and_raise("REAL GOOGLE DRIVE CALL BLOCKED BY SPECS")
  end

  def fake_file(filename:, size:)
    double(
      blank?: false,
      original_filename: filename,
      size: size
    )
  end

  describe "#extract_original_filename" do
    it "removes the uuid prefix" do
      name = "12345678-1234-1234-1234-123456789abc-report.pdf"
      expect(controller.send(:extract_original_filename, name)).to eq("report.pdf")
    end

    it "returns the original name when there is no uuid prefix" do
      expect(controller.send(:extract_original_filename, "report.pdf")).to eq("report.pdf")
    end
  end

  describe "#sanitize_archive_path" do
    it "returns file when the path is blank" do
      expect(controller.send(:sanitize_archive_path, "   ")).to eq("file")
    end

    it "cleans backslashes, leading slashes, and traversal fragments" do
      result = controller.send(:sanitize_archive_path, "  /tmp\\folder\\..\\name.txt  ")

      expect(result).to include("tmp/")
      expect(result).to include("folder/")
      expect(result).to include("name.txt")
      expect(result).not_to include("\\")
      expect(result).not_to start_with("/")
      expect(result).not_to include("..")
    end
  end

  describe "#validate_input_file!" do
    it "raises when no file is provided" do
      expect do
        controller.send(:validate_input_file!, nil, "1")
      end.to raise_error(ArgumentError, "Please select a file to upload.")
    end

    it "raises when the file is too large" do
      file = fake_file(
        filename: "report.pdf",
        size: described_class::MAX_FILE_SIZE_BYTES + 1
      )

      expect do
        controller.send(:validate_input_file!, file, "1")
      end.to raise_error(ArgumentError, "File exceeds 1 GB size limit.")
    end

    it "raises when slot 1 is not a pdf" do
      file = fake_file(filename: "report.dcm", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "1")
      end.to raise_error(ArgumentError, "PDF file must have .pdf extension.")
    end

    it "accepts any file extension for slot 2" do
      file = fake_file(filename: "report.txt", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "2")
      end.not_to raise_error
    end

    it "raises when slot is invalid" do
      file = fake_file(filename: "report.pdf", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "3")
      end.to raise_error(ArgumentError, "Invalid upload slot.")
    end
  end

  describe "DELETE #remove" do
    it "deletes the image file when there are no drive file ids" do
      image_file = double("ImageFile", drive_file_ids: [], destroy!: true)
      allow(ImageFile).to receive(:find).and_return(image_file)

      delete :remove, params: { image_file_id: 1 }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq("File deleted.")
    end

    it "returns an alert when the image file cannot be found" do
      allow(ImageFile).to receive(:find).and_raise(StandardError, "boom")

      delete :remove, params: { image_file_id: 1 }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:alert]).to eq("File delete failed: boom")
    end
  end

  describe "#send_dicom_archive" do
    it "raises when there are no DICOM files" do
      image_file = double("ImageFile", dicom_files_metadata: [], job_id: 1)
      drive_service = double("DriveService")

      expect do
        controller.send(:send_dicom_archive, image_file, drive_service)
      end.to raise_error("No DICOM files were found for this record.")
    end
  end

  describe "#create_job_folder" do
    it "stores the created folder id on the job" do
      job = double(
        id: 1,
        title: "Test Job",
        created_at: Time.current,
        update: true
      )

      drive_service = double("DriveService")
      created_folder = double(id: "folder-123")

      allow(drive_service).to receive(:create_file).and_return(created_folder)
      expect(job).to receive(:update).with(google_drive_folder_id: "folder-123")

      controller.create_job_folder(drive_service, job)
    end

    it "does not raise when folder creation fails" do
      job = double(id: 1, title: "Test Job", created_at: Time.current)
      drive_service = double("DriveService")

      allow(drive_service).to receive(:create_file).and_raise(StandardError, "boom")
      allow(Rails.logger).to receive(:error)

      expect do
        controller.create_job_folder(drive_service, job)
      end.not_to raise_error
    end
  end
end