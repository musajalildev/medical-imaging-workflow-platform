require "rails_helper"

RSpec.describe CancelledJobsController, type: :controller do
  let(:cancelled_job_double) do
    double("CancelledJob", save: true, update: true, destroy!: true)
  end

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    job = cancelled_job_double

    CancelledJob.singleton_class.send(:define_method, :all) do
      []
    end

    CancelledJob.singleton_class.send(:define_method, :find) do |_id|
      job
    end

    CancelledJob.singleton_class.send(:define_method, :new) do |_attrs = {}|
      job
    end
  end

  describe "GET #index" do
    it "sets cancelled jobs" do
      get :index
      expect(controller.instance_variable_get(:@cancelled_jobs)).to eq([])
    end
  end

  describe "GET #show" do
    it "sets a cancelled job" do
      get :show, params: { id: 1 }
      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end

  describe "GET #new" do
    it "assigns a new cancelled job" do
      get :new
      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end

  describe "GET #edit" do
    it "assigns a cancelled job" do
      get :edit, params: { id: 1 }
      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        cancelled_job: {
          job_id: 1,
          cancel_reason: "Test reason"
        }
      }

      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        cancelled_job: {
          job_id: 1,
          cancel_reason: "Updated reason"
        }
      }

      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@cancelled_job)).to eq(cancelled_job_double)
    end
  end
end