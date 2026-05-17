# spec/controllers/complete_jobs_controller_spec.rb
require "rails_helper"

RSpec.describe CompleteJobsController, type: :controller do
  let(:complete_job_double) do
    double("CompleteJob", save: true, update: true, destroy!: true)
  end

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    job = complete_job_double

    CompleteJob.singleton_class.send(:define_method, :all) do
      []
    end

    CompleteJob.singleton_class.send(:define_method, :find) do |_id|
      job
    end

    CompleteJob.singleton_class.send(:define_method, :new) do |_attrs = {}|
      job
    end
  end

  describe "GET #index" do
    it "sets complete jobs" do
      get :index
      expect(controller.instance_variable_get(:@complete_jobs)).to eq([])
    end
  end

  describe "GET #show" do
    it "sets a complete job" do
      get :show, params: { id: 1 }
      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end

  describe "GET #new" do
    it "assigns a new complete job" do
      get :new
      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end

  describe "GET #edit" do
    it "assigns a complete job" do
      get :edit, params: { id: 1 }
      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        complete_job: {
          job_id: 1
        }
      }

      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        complete_job: {
          job_id: 1
        }
      }

      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@complete_job)).to eq(complete_job_double)
    end
  end
end