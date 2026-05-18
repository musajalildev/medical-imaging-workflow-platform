require "rails_helper"

RSpec.describe JobsController, type: :controller do
  let(:client_user) { create(:user, role: :client) }
  let(:operator_user) { create(:user, role: :operator) }
  let(:admin_user) { create(:user, role: :admin) }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:attach_uploaded_file)
    allow(UserMailer).to receive_message_chain(:send_new_job_email, :deliver_later)
    allow(UserMailer).to receive_message_chain(:send_job_status_change_email, :deliver_later)
    allow(UserMailer).to receive_message_chain(:send_job_completed_email, :deliver_later)
    allow(UserMailer).to receive_message_chain(:send_job_cancelled_email, :deliver_later)
  end

  describe "GET #new" do
    it "allows a client" do
      sign_in client_user
      get :new
      expect(response).to have_http_status(:success)
    end

    it "redirects non-clients" do
      sign_in operator_user
      get :new
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #edit" do
    let(:job) { create(:job, client: client_user, title: "Test", description: "Desc", status: :pending) }

    it "allows a client" do
      sign_in client_user
      get :edit, params: { id: job.id }
      expect(response).to have_http_status(:success)
    end

    it "redirects non-clients" do
      sign_in operator_user
      get :edit, params: { id: job.id }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #index" do
    let!(:client_active_job) do
      create(:job, client: client_user, title: "Active Job", description: "Desc", status: :pending)
    end

    let!(:client_draft_job) do
      create(:job, client: client_user, title: "Draft Job", description: nil, status: :draft)
    end

    let!(:operator_assigned_job) do
      create(:job, client: client_user, operator: operator_user, title: "Assigned Job", description: "Desc", status: :assigned)
    end

    it "shows active jobs for a client by default" do
      sign_in client_user
      get :index

      expect(controller.instance_variable_get(:@tab)).to eq("active")
      expect(controller.instance_variable_get(:@jobs)).to include(client_active_job)
      expect(controller.instance_variable_get(:@jobs)).not_to include(client_draft_job)
    end

    it "shows drafts for a client" do
      sign_in client_user
      get :index, params: { tab: "drafts" }

      expect(controller.instance_variable_get(:@tab)).to eq("drafts")
      expect(controller.instance_variable_get(:@jobs)).to include(client_draft_job)
    end

    it "shows assigned jobs for an operator" do
      sign_in operator_user
      get :index

      expect(controller.instance_variable_get(:@tab)).to eq("assigned")
      expect(controller.instance_variable_get(:@jobs)).to include(operator_assigned_job)
    end
  end

  describe "POST #create" do
    it "creates a draft job for a client" do
      sign_in client_user

      expect do
        post :create, params: {
          job: {
            title: "Draft Job",
            description: nil
          },
          save_as_draft: "1",
          uploaded_files_json: "[]"
        }
      end.to change(Job, :count).by(1)

      expect(Job.last.status).to eq("draft")
    end

    it "redirects non-clients" do
      sign_in operator_user

      post :create, params: {
        job: {
          title: "Test Job",
          description: "Test Description"
        },
        uploaded_files_json: "[]"
      }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH #update" do
    let(:job) { create(:job, client: client_user, title: "Original", description: "Original description", status: :pending) }

    it "updates a job for a client" do
      sign_in client_user

      patch :update, params: {
        id: job.id,
        job: {
          title: "Updated Title",
          description: "Updated Description"
        },
        uploaded_files_json: "[]"
      }

      job.reload
      expect(job.title).to eq("Updated Title")
    end

    it "redirects non-clients" do
      sign_in operator_user

      patch :update, params: {
        id: job.id,
        job: { title: "Updated Title" },
        uploaded_files_json: "[]"
      }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH #update_status" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Status Job", description: "Desc", status: :pending)
    end

    before do
      sign_in operator_user
    end

    it "updates the status" do
      patch :update_status, params: {
        id: job.id,
        job: {
          status: "assigned",
          custom_status: ""
        }
      }

      job.reload
      expect(job.status).to eq("assigned")
    end
  end

  describe "PATCH #complete_job" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Complete Job", description: "Desc", status: :assigned)
    end

    before do
      sign_in operator_user
    end

    it "marks the job complete" do
      patch :complete_job, params: { id: job.id }

      job.reload
      expect(job.status).to eq("complete")
    end
  end

  describe "PATCH #cancel_job" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Cancelable Job", description: "Desc", status: :assigned)
    end

    before do
      sign_in admin_user
    end

    it "cancels a job" do
      patch :cancel_job, params: { id: job.id }

      job.reload
      expect(job.status).to eq("cancelled")
    end
  end

  describe "PATCH #submit_draft" do
    let(:draft_job) do
      create(:job, client: client_user, title: "Draft Job", description: nil, status: :draft)
    end

    it "rejects non-draft jobs" do
      sign_in client_user
      live_job = create(:job, client: client_user, title: "Live Job", description: "Desc", status: :pending)

      patch :submit_draft, params: { id: live_job.id }

      expect(response).to redirect_to(root_path)
    end

    it "rejects draft jobs without files" do
      sign_in client_user

      patch :submit_draft, params: { id: draft_job.id }

      expect(response).to redirect_to(job_path(draft_job))
    end
  end

  describe "DELETE #destroy" do
    let(:job) do
      create(:job, client: client_user, title: "Destroy Job", description: "Desc", status: :pending)
    end

    before do
      sign_in admin_user
      allow(controller).to receive(:purge_job_files_from_drive).and_return(nil)
    end

    it "redirects to jobs_path when destroy runs" do
      allow_any_instance_of(Job).to receive(:destroy!).and_return(true)

      delete :destroy, params: { id: job.id }

      expect(response).to redirect_to(jobs_path)
    end
  end

  describe "POST #upload_output" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Output Job", description: "Desc", status: :pending)
    end

    it "rejects non-operators" do
      sign_in client_user

      post :upload_output, params: { id: job.id }

      expect(response).to redirect_to(job_path(job))
    end

    it "rejects completed jobs" do
      sign_in operator_user
      job.update!(status: :complete)

      post :upload_output, params: { id: job.id }

      expect(response).to redirect_to(job_path(job))
    end
  end
end