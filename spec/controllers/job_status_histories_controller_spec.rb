require "rails_helper"

RSpec.describe JobStatusHistoriesController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    job_status_history = double(
      "JobStatusHistory",
      save: true,
      update: true,
      destroy!: true
    )

    stub_const("JobStatusHistory", Class.new)

    JobStatusHistory.define_singleton_method(:all) do
      []
    end

    JobStatusHistory.define_singleton_method(:find) do |_id|
      job_status_history
    end

    JobStatusHistory.define_singleton_method(:new) do |_attrs = {}|
      job_status_history
    end
  end

  describe "GET #index" do
    it "assigns job status histories" do
      get :index

      expect(controller.instance_variable_get(:@job_status_histories)).to eq([])
    end
  end

  describe "GET #show" do
    it "assigns a job status history" do
      get :show, params: { id: 1 }

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end

  describe "GET #new" do
    it "assigns a new job status history" do
      get :new

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end

  describe "GET #edit" do
    it "assigns a job status history" do
      get :edit, params: { id: 1 }

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        job_status_history: {
          job_id: 1,
          old_status: "pending",
          new_status: "complete",
          initiator_id: 2
        }
      }

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        job_status_history: {
          job_id: 1,
          old_status: "pending",
          new_status: "complete",
          initiator_id: 2
        }
      }

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@job_status_history)).not_to be_nil
    end
  end
end