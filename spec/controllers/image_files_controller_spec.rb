# spec/controllers/image_files_controller_spec.rb
require "rails_helper"

RSpec.describe ImageFilesController, type: :controller do
  let(:image_file_double) do
    double("ImageFile", save: true, update: true, destroy!: true)
  end

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    allow(ImageFile).to receive(:all).and_return([])
    allow(ImageFile).to receive(:find).and_return(image_file_double)
    allow(ImageFile).to receive(:new).and_return(image_file_double)
  end

  describe "GET #index" do
    it "sets image files" do
      get :index
      expect(controller.instance_variable_get(:@image_files)).to eq([])
    end
  end

  describe "GET #show" do
    it "sets an image file" do
      get :show, params: { id: 1 }
      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end

  describe "GET #new" do
    it "assigns a new image file" do
      get :new
      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end

  describe "GET #edit" do
    it "assigns an image file" do
      get :edit, params: { id: 1 }
      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        image_file: {
          job_id: 1,
          file_path: "test/path",
          file_type: "pdf"
        }
      }

      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        image_file: {
          job_id: 1,
          file_path: "updated/path",
          file_type: "dicom"
        }
      }

      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@image_file)).to eq(image_file_double)
    end
  end
end