require "rails_helper"

RSpec.describe FilesController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
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

    # current version no longer requires dicom in second slot
    # it "raises when slot 2 is not a dicom" do
    #   file = fake_file(filename: "report.pdf", size: 100)

    #   expect do
    #     controller.send(:validate_input_file!, file, "2")
    #   end.to raise_error(ArgumentError, "DICOM file must have .dcm extension.")
    # end

    it "raises when slot is invalid" do
      file = fake_file(filename: "report.pdf", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "3")
      end.to raise_error(ArgumentError, "Invalid upload slot.")
    end

    it "accepts a valid pdf for slot 1" do
      file = fake_file(filename: "report.pdf", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "1")
      end.not_to raise_error
    end

    it "accepts a valid dicom for slot 2" do
      file = fake_file(filename: "scan.dcm", size: 100)

      expect do
        controller.send(:validate_input_file!, file, "2")
      end.not_to raise_error
    end
  end

  describe "DELETE #remove" do
    it "destroys the image file when there is no drive file id" do
      image_file = double("ImageFile", drive_file_ids: nil, destroy!: true)
      allow(ImageFile).to receive(:find).and_return(image_file)

      delete :remove, params: { image_file_id: 1 }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to eq("File deleted.")
    end
  end
end