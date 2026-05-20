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

  describe "POST #upload" do
    before do
      allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return("existing_folder_id")

      # Stub DriveService instantiation
      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive_service)
      allow(drive_service).to receive(:client_options).and_return(double(application_name: nil, "application_name=" => nil))

      # Stub credentials
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(credentials)
      allow(credentials).to receive(:fetch_access_token!)
      allow(drive_service).to receive(:authorization=)

      # Stub file creation
      allow(drive_service).to receive(:create_file).and_return(created_folder)

      # Prevent real file reads
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(Rails.root.join("service_account.json")).and_return(double)

      # Stub random name generation
      allow(SecureRandom).to receive(:uuid).and_return("random")
    end

    # Mock Job
    let(:job) { create(:job, title: "some title", google_drive_folder_id: "existing_folder_id") }
    # Mock Google API objects
    let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
    let(:credentials)   { instance_double(Google::Auth::ServiceAccountCredentials) }
    let(:created_folder) do
      double(
        id: "test_folder_id",
        web_view_link: "http://example.com",
        web_content_link: nil
      )
    end
    let(:mock_file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/factories/files/test.pdf"),
        "application/pdf"
      )
    end

    context "when all params are passed", js: true do
      it "creates the filename with new random name" do
        expect(Google::Apis::DriveV3::File).to receive(:new).with(
          hash_including(name: "random-test.pdf")
        )

        post :upload, params: { file: mock_file, slot: "2", job_id: job.id, relative_path: "some path" }
      end

      it "finishes with success" do
        post :upload, params: { file: mock_file, slot: "2", job_id: job.id, relative_path: "some path" }
        
        json = JSON.parse(response.body, symbolize_names: true)
        expect(json[:success]).to eq(true)
      end
    end
  end

  describe "#GET download" do
    let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
    let(:credentials)   { instance_double(Google::Auth::ServiceAccountCredentials) }
    let(:metadata) { double(name: "random-report.pdf", mime_type: "application/pdf") }

    before do
      # Stub DriveService instantiation
      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive_service)
      allow(drive_service).to receive(:client_options).and_return(double(application_name: nil, "application_name=" => nil))

      # Stub credentials
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(credentials)
      allow(credentials).to receive(:fetch_access_token!)
      allow(drive_service).to receive(:authorization=)

      # First get_file call returns metadata
      allow(drive_service).to receive(:get_file).with(
        "random", hash_including(fields: "name,mimeType")
      ).and_return(metadata)

      # Second get_file call writes to the io object
      allow(drive_service).to receive(:get_file).with(
        "random", hash_including(download_dest: anything)
      ) do |_id, kwargs|
        kwargs[:download_dest].write("fake file content")
      end
    end

    it "sends the file with the original filename stripped of uuid prefix" do
      get :download, params: { file_id: "random" }
      expect(response.headers["Content-Disposition"]).to include("report.pdf")
    end
  end

  describe "DELETE #remove" do
    let(:drive_service) { instance_double(Google::Apis::DriveV3::DriveService) }
    let(:credentials)   { instance_double(Google::Auth::ServiceAccountCredentials) }
    let(:image_file)    { double("ImageFile", drive_file_ids: ["random"], destroy!: true) }

    before do
      allow(ImageFile).to receive(:find).and_return(image_file)

      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive_service)
      allow(drive_service).to receive(:client_options).and_return(double(application_name: nil, "application_name=" => nil))

      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(credentials)
      allow(credentials).to receive(:fetch_access_token!)
      allow(drive_service).to receive(:authorization=)

      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with(Rails.root.join("service_account.json")).and_return(double)
    end

    context "when the file can be deleted" do
      let(:metadata) do
        double(capabilities: double(can_delete: true, can_trash: false), parents: [])
      end

      before { allow(drive_service).to receive(:get_file).and_return(metadata) }

      it "deletes the file from drive and destroys the image file" do
        allow(drive_service).to receive(:delete_file)
        expect(drive_service).to receive(:delete_file).with("random", supports_all_drives: true)
        expect(image_file).to receive(:destroy!)

        delete :remove, params: { image_file_id: 1 }

        expect(response).to redirect_to(jobs_path)
        expect(flash[:notice]).to eq("File deleted.")
      end
    end

    context "when the file can only be trashed" do
      let(:metadata) do
        double(capabilities: double(can_delete: false, can_trash: true), parents: [])
      end

      before { allow(drive_service).to receive(:get_file).and_return(metadata) }

      it "trashes the file and destroys the image file" do
        allow(drive_service).to receive(:update_file)
        expect(drive_service).to receive(:update_file).with(
          "random",
          anything,
          hash_including(supports_all_drives: true, fields: "id")
        )

        delete :remove, params: { image_file_id: 1 }
      end
    end

    context "when the file can only be removed from the folder" do
      let(:metadata) do
        double(
          capabilities: double(can_delete: false, can_trash: false),
          parents: [FilesController::FOLDER_ID]
        )
      end

      before { allow(drive_service).to receive(:get_file).and_return(metadata) }

      it "removes the file from the folder and destroys the image file" do
        allow(drive_service).to receive(:update_file)
        expect(drive_service).to receive(:update_file).with(
          "random",
          anything,
          hash_including(remove_parents: FilesController::FOLDER_ID)
        )

        delete :remove, params: { image_file_id: 1 }
      end
    end

    context "when no drive action is possible" do
      let(:metadata) do
        double(
          capabilities: double(can_delete: false, can_trash: false),
          parents: []
        )
      end

      before { allow(drive_service).to receive(:get_file).and_return(metadata) }

      it "redirects with an alert" do
        delete :remove, params: { image_file_id: 1 }

        expect(response).to redirect_to(jobs_path)
        expect(flash[:alert]).to include("File delete failed")
      end
    end

    context "when there are no drive file ids" do
      let(:image_file) { double("ImageFile", drive_file_ids: [], destroy!: true) }

      it "destroys the image file without touching drive" do
        expect(drive_service).not_to receive(:delete_file)
        expect(image_file).to receive(:destroy!)

        delete :remove, params: { image_file_id: 1 }

        expect(response).to redirect_to(jobs_path)
        expect(flash[:notice]).to eq("File deleted.")
      end
    end
  end

  describe "#send_dicom_archive" do
    let(:drive_service) { double("DriveService") }
    let(:file_metadata) { double(name: "random-report.dcm") }
    let(:entries) do
      [{ "file_id" => "random", "relative_path" => "scans/report.dcm" }]
    end
    let(:image_file) do
      double("ImageFile", dicom_files_metadata: entries, job_id: 1)
    end

    before do
      allow(drive_service).to receive(:get_file) do |_id, kwargs|
        if kwargs[:download_dest]
          kwargs[:download_dest].write("fake dicom content")
        else
          file_metadata
        end
      end

      allow(Rails.logger).to receive(:info)
    end

    it "raises when there are no DICOM files" do
      empty_image_file = double("ImageFile", dicom_files_metadata: [])

      expect do
        controller.send(:send_dicom_archive, empty_image_file, drive_service)
      end.to raise_error("No DICOM files were found for this record.")
    end

    it "sends a tar.gz archive with the correct filename" do
      allow(controller).to receive(:send_data)
      expect(controller).to receive(:send_data).with(
        anything,
        hash_including(
          filename: "job-1-dicom-files.tar.gz",
          type: "application/gzip",
          disposition: "attachment"
        )
      )

      controller.send(:send_dicom_archive, image_file, drive_service)
    end

    it "skips entries with no file_id" do
      allow(controller).to receive(:send_data)
      entries_with_blank = [{ "file_id" => nil, "relative_path" => "scans/report.dcm" }]
      image_file_with_blank = double("ImageFile", dicom_files_metadata: entries_with_blank, job_id: 1)

      expect(drive_service).not_to receive(:get_file)

      controller.send(:send_dicom_archive, image_file_with_blank, drive_service)
    end

    it "raises and logs when a file download fails" do
      allow(drive_service).to receive(:get_file).and_raise(StandardError, "download failed")
      allow(Rails.logger).to receive(:error)

      expect do
        controller.send(:send_dicom_archive, image_file, drive_service)
      end.to raise_error(StandardError, "download failed")

      expect(Rails.logger).to have_received(:error).with(match(/Error adding file random to archive/))
    end
  end
end