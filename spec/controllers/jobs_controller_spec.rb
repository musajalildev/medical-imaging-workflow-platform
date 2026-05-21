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

  describe "PATCH #self_assign" do
    let(:job) do
      create(:job, client: client_user, operator: nil, title: "Unassigned Job", description: "Desc", status: :pending)
    end

    it "rejects a job when already assigned to an operator" do
      job.update!(operator: operator_user)

      patch :self_assign, params: { id: job.id }

      expect(response).to redirect_to(root_path)
    end

    it "assigns this job to the operator when no operator is assigned" do
      allow(controller).to receive(:current_user).and_return(operator_user)
      # record how many jobs this operator had before method call
      before_count = Job.where(operator: operator_user).count

      patch :self_assign, params: { id: job.id }

      expect(response).to redirect_to(jobs_path(tab: "unassigned"))
      expect(Job.where(operator: operator_user).count).to eq(before_count + 1) 
    end
  end

  describe "PATCH #unassign" do
    before do
      allow(controller).to receive(:current_user).and_return(operator_user)
    end
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Unassigned Job", description: "Desc", status: :assigned)
    end

    it "unassigns current operator from the job" do
      # record how many jobs this operator had before method call
      job # need to force lazy eval to make job
      before_count = Job.where(operator: operator_user).count

      patch :unassign, params: { id: job.id }

      expect(response).to redirect_to(jobs_path(tab: "assigned"))
      expect(Job.where(operator: operator_user).count).to eq(before_count - 1) 
    end

    it "sets the jobs status to pending" do

      patch :unassign, params: { id: job.id }

      expect(job.reload.status).to eq("pending")
      expect(job.status).not_to eq("assigned")
    end

    it "rejects when job is assigned to another operator" do
      other_operator_user = create(:user, role: :operator)
      job.update!(operator: other_operator_user)

      patch :unassign, params: { id: job.id }
    
      expect(response).to redirect_to(root_path)
    end
  end

  describe "PATCH #re_assign" do
    before do
      allow(controller).to receive(:current_user).and_return(admin_user)
    end
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Unassigned Job", description: "Desc", status: :assigned)
    end
    let(:other_operator_user) { create(:user, role: :operator) }

    it "re-assigns the operator from the current to selected" do
      patch :re_assign, params: { id: job.id, operator_id: other_operator_user }

      expect(job.reload.operator).to eq(other_operator_user)
      expect(job.status).to eq("assigned")
      expect(response).to redirect_to(job_path(job))
      expect(flash[:notice]).to eq("Operator reassigned successfully.")
    end

    it "removes the current operator when no operator selected" do
      patch :re_assign, params: { id: job.id, operator_id: "" }

      expect(job.reload.operator).to eq(nil)
      expect(job.status).to eq("pending")
      expect(response).to redirect_to(job_path(job))
      expect(flash[:notice]).to eq("Operator dropped successfully.")
    end

    it "updates the operator from none to selected" do
      job.update!(operator: nil)

      patch :re_assign, params: { id: job.id, operator_id: operator_user }

      expect(job.reload.operator).to eq(operator_user)
      expect(job.status).to eq("assigned")
      expect(response).to redirect_to(job_path(job))
      expect(flash[:notice]).to eq("Operator assigned successfully.")
    end
  end

  describe "PATCH #revert_to_draft" do
    before do
      sign_in client_user
    end
    let(:job) do
      create(:job, client: client_user, operator: nil, title: "Unassigned Job", description: "Desc", status: :pending)
    end
    it "redirects with alert when job is not pending with no operator" do
      job.update(operator: operator_user, status: :assigned)

      patch :revert_to_draft, params: { id: job.id }

      expect(response).to redirect_to(root_path)
    end

    it "updates the jobs status to draft" do
      patch :revert_to_draft, params: { id: job.id }

      expect(job.reload.status).to eq("draft")
      expect(response).to redirect_to(job_path(job))
      expect(flash[:notice]).to eq("Job was reverted to draft.")
    end
  end

  describe "GET #show" do
    let(:job) { create(:job, client: client_user, title: "Show Job", description: "Desc", status: :pending) }

    it "renders successfully for the owning client" do
      sign_in client_user
      get :show, params: { id: job.id }

      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@user)).to eq(client_user)
    end

    it "renders successfully for an operator" do
      sign_in operator_user
      get :show, params: { id: job.id }

      expect(response).to have_http_status(:success)
    end

    it "renders successfully for an admin" do
      sign_in admin_user
      get :show, params: { id: job.id }

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #index (additional paths)" do
    it "shows all non-draft jobs for admin" do
      sign_in admin_user
      pending_job = create(:job, client: client_user, operator: nil, title: "Pending", description: "Desc", status: :pending)
      draft_job   = create(:job, client: client_user, operator: nil, title: "Draft",   description: nil,   status: :draft)

      get :index

      jobs = controller.instance_variable_get(:@jobs)
      expect(jobs).to include(pending_job)
      expect(jobs).not_to include(draft_job)
    end

    it "shows unassigned (pending) jobs for operator on unassigned tab" do
      sign_in operator_user
      pending_job = create(:job, client: client_user, operator: nil, title: "Pending", description: "Desc", status: :pending)

      get :index, params: { tab: "unassigned" }

      expect(controller.instance_variable_get(:@tab)).to eq("unassigned")
      expect(controller.instance_variable_get(:@jobs)).to include(pending_job)
    end

    it "filters by title search" do
      sign_in admin_user
      matching     = create(:job, client: client_user, operator: nil, title: "DICOM Scan",  description: "Desc", status: :pending)
      non_matching = create(:job, client: client_user, operator: nil, title: "Other Job",   description: "Desc", status: :pending)

      get :index, params: { search: "DICOM", search_by: "title" }

      jobs = controller.instance_variable_get(:@jobs)
      expect(jobs).to include(matching)
      expect(jobs).not_to include(non_matching)
    end

    it "filters by default search (no search_by) across title and client name" do
      sign_in admin_user
      unique_client = create(:user, role: :client, givenname: "ZephyrClient")
      matching      = create(:job, client: unique_client, operator: nil, title: "Job", description: "Desc", status: :pending)
      non_matching  = create(:job, client: client_user,   operator: nil, title: "Job", description: "Desc", status: :pending)

      get :index, params: { search: "ZephyrClient" }

      jobs = controller.instance_variable_get(:@jobs)
      expect(jobs).to include(matching)
      expect(jobs).not_to include(non_matching)
    end

    it "sorts jobs ascending by created_at" do
      sign_in admin_user
      get :index, params: { sort: "asc" }

      expect(response).to have_http_status(:success)
    end

    it "filters by status" do
      sign_in admin_user
      assigned_job = create(:job, client: client_user, operator: operator_user, title: "Assigned", description: "Desc", status: :assigned)
      pending_job  = create(:job, client: client_user, operator: nil,           title: "Pending",  description: "Desc", status: :pending)

      get :index, params: { status: "assigned" }

      jobs = controller.instance_variable_get(:@jobs)
      expect(jobs).to include(assigned_job)
      expect(jobs).not_to include(pending_job)
    end
  end

  describe "POST #create (additional paths)" do
    before { sign_in client_user }

    it "creates a pending job when both files are present" do
      uploaded_json = JSON.generate([
        { slot: 1, file_id: "pdf-id-123", file_url: "https://drive.google.com/file/d/pdf-id-123/view", file_type: "application/pdf" },
        { slot: 2, file_id: "dcm-id-456", file_url: "https://drive.google.com/file/d/dcm-id-456/view", file_type: "application/dicom", files: [] }
      ])

      expect do
        post :create, params: {
          job: { title: "Full Job", description: "Desc" },
          create_job: "1",
          uploaded_files_json: uploaded_json
        }
      end.to change(Job, :count).by(1)

      expect(Job.last.status).to eq("pending")
      expect(response).to redirect_to(job_path(Job.last))
    end

    it "renders new when files are missing for a pending submission" do
      post :create, params: {
        job: { title: "No Files Job", description: "Desc" },
        create_job: "1",
        uploaded_files_json: "[]"
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "renders new when the job itself is invalid (blank title)" do
      post :create, params: {
        job: { title: "", description: "Desc" },
        save_as_draft: "1",
        uploaded_files_json: "[]"
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH #update (additional paths)" do
    let(:job) { create(:job, client: client_user, title: "Original", description: "Original description", status: :pending) }

    it "renders edit when the update fails" do
      sign_in client_user
      allow_any_instance_of(Job).to receive(:update).and_return(false)

      patch :update, params: {
        id: job.id,
        job: { title: "Updated", description: "Updated" },
        uploaded_files_json: "[]"
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH #update_status (additional paths)" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Status Job", description: "Desc", status: :assigned)
    end

    before { sign_in operator_user }

    it "stores a custom status and keeps it when status is custom" do
      patch :update_status, params: {
        id: job.id,
        job: { status: "custom", custom_status: "Awaiting CT" }
      }

      job.reload
      expect(job.status).to eq("custom")
      expect(job.custom_status).to eq("Awaiting CT")
    end

    it "clears custom_status when switching away from custom" do
      job.update!(status: :custom, custom_status: "Old custom")

      patch :update_status, params: {
        id: job.id,
        job: { status: "in_progress", custom_status: "" }
      }

      expect(job.reload.custom_status).to be_nil
    end

    it "does not create a status history record when status is unchanged" do
      job.update!(status: :assigned)

      expect {
        patch :update_status, params: {
          id: job.id,
          job: { status: "assigned", custom_status: "" }
        }
      }.not_to change(JobStatusHistory, :count)
    end

    it "responds with unprocessable when update fails" do
      allow_any_instance_of(Job).to receive(:update).and_return(false)

      patch :update_status, params: {
        id: job.id,
        job: { status: "in_progress", custom_status: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH #cancel_job (additional paths)" do
    before do
      allow(UserMailer).to receive_message_chain(:send_job_dropped_email, :deliver_later)
      allow(Delayed::Job).to receive(:enqueue)
    end

    it "destroys a draft job and redirects to drafts tab" do
      sign_in admin_user
      draft_job = create(:job, client: client_user, operator: nil, title: "Draft", description: nil, status: :draft)

      expect {
        patch :cancel_job, params: { id: draft_job.id }
      }.to change(Job, :count).by(-1)

      expect(response).to redirect_to(jobs_path(tab: "drafts"))
      expect(flash[:notice]).to eq("Draft was deleted.")
    end

    it "allows an operator to cancel their assigned job" do
      sign_in operator_user
      job = create(:job, client: client_user, operator: operator_user, title: "Op Job", description: "Desc", status: :assigned)

      patch :cancel_job, params: { id: job.id }

      expect(job.reload.status).to eq("cancelled")
      expect(response).to redirect_to(job_path(job))
    end

    it "allows admin to cancel a job with an operator, updating status to cancelled" do
      sign_in admin_user
      job = create(:job, client: client_user, operator: operator_user, title: "Admin Job", description: "Desc", status: :assigned)

      patch :cancel_job, params: { id: job.id }

      expect(job.reload.status).to eq("cancelled")
      expect(response).to redirect_to(job_path(job))
    end
  end

  describe "PATCH #complete_job (additional paths)" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Complete Job", description: "Desc", status: :assigned)
    end

    before do
      sign_in operator_user
      allow(Delayed::Job).to receive(:enqueue)
    end

    it "responds with unprocessable and alert when complete fails" do
      allow_any_instance_of(Job).to receive(:update).and_return(false)

      patch :complete_job, params: { id: job.id }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "allows admin to complete a job with an operator, updating status to complete" do
      sign_in admin_user
      job_with_op = create(:job, client: client_user, operator: operator_user, title: "Admin Complete", description: "Desc", status: :assigned)

      patch :complete_job, params: { id: job_with_op.id }

      expect(job_with_op.reload.status).to eq("complete")
      expect(response).to redirect_to(job_path(job_with_op))
    end
  end

  describe "DELETE #destroy (additional paths)" do
    let(:job) do
      create(:job, client: client_user, title: "Destroy Job", description: "Desc", status: :pending)
    end

    before { sign_in admin_user }

    it "redirects with alert when drive purge fails" do
      allow(controller).to receive(:purge_job_files_from_drive).and_return("Permission denied")

      delete :destroy, params: { id: job.id }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:alert]).to include("Drive cleanup failed")
    end

    it "calls rename_drive_folder_deleted before destroying the job" do
      allow(controller).to receive(:purge_job_files_from_drive).and_return(nil)
      allow(controller).to receive(:rename_drive_folder_deleted)
      allow_any_instance_of(Job).to receive(:destroy!).and_return(true)

      delete :destroy, params: { id: job.id }

      expect(controller).to have_received(:rename_drive_folder_deleted)
      expect(response).to redirect_to(jobs_path)
    end
  end

  describe "POST #upload_output (additional paths)" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user, title: "Output Job", description: "Desc", status: :assigned)
    end

    it "redirects with alert when no file is provided" do
      sign_in operator_user

      post :upload_output, params: { id: job.id }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:alert]).to eq("Please select an output file.")
    end

    it "rejects an operator who is not assigned to the job" do
      other_operator = create(:user, role: :operator)
      sign_in other_operator

      post :upload_output, params: { id: job.id }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:alert]).to eq("You are not authorized to upload report files for this job.")
    end
  end

  describe "PATCH #submit_draft (additional paths)" do
    before { sign_in client_user }

    it "submits a draft with both files present" do
      draft_job = create(:job, client: client_user, operator: nil, title: "Draft", description: "Desc", status: :draft)
      create(:image_file, job: draft_job, file_path: "https://drive.google.com/pdf",  file_type: '{"slot":"1"}')
      create(:image_file, job: draft_job, file_path: "https://drive.google.com/dicom", file_type: '{"slot":"2"}')

      patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: "[]" }

      expect(draft_job.reload.status).to eq("pending")
      expect(response).to redirect_to(job_path(draft_job))
      expect(flash[:notice]).to eq("Job submitted successfully.")
    end
  end

  # ── purge_job_files_from_drive + purge_drive_file! ────────────────────────
  describe "DELETE #destroy (drive purge behavior)" do
    let(:drive_service) { double("drive_service") }

    before do
      sign_in admin_user
      allow(controller).to receive(:build_drive_service).and_return(drive_service)
      allow(controller).to receive(:rename_drive_folder_deleted)
    end

    it "succeeds immediately when the job has no image files with drive IDs" do
      job = create(:job, client: client_user, title: "Empty", description: "Desc", status: :pending)

      delete :destroy, params: { id: job.id }

      expect(response).to redirect_to(jobs_path)
      expect(flash[:notice]).to include("successfully deleted")
    end

    context "when the job has an image file with a drive ID" do
      let!(:job) do
        j = create(:job, client: client_user, title: "Drive Job", description: "Desc", status: :pending)
        create(:image_file, job: j,
               file_path: "https://drive.google.com/file/d/file-abc/view",
               file_type: '{"file_id":"file-abc"}')
        j
      end

      it "calls delete_file when can_delete is true" do
        caps = double(can_delete: true, can_trash: false)
        allow(drive_service).to receive(:get_file)
          .and_return(double(capabilities: caps, parents: []))
        allow(drive_service).to receive(:delete_file)

        delete :destroy, params: { id: job.id }

        expect(drive_service).to have_received(:delete_file)
          .with("file-abc", supports_all_drives: true)
        expect(response).to redirect_to(jobs_path)
      end

      it "trashes the file when can_trash is true and can_delete is false" do
        caps = double(can_delete: false, can_trash: true)
        allow(drive_service).to receive(:get_file)
          .and_return(double(capabilities: caps, parents: []))
        allow(drive_service).to receive(:update_file)

        delete :destroy, params: { id: job.id }

        expect(drive_service).to have_received(:update_file)
          .with("file-abc", instance_of(Google::Apis::DriveV3::File),
                supports_all_drives: true, fields: "id")
        expect(response).to redirect_to(jobs_path)
      end

      it "removes the file from the shared folder when it cannot be deleted or trashed" do
        stub_const("FilesController::FOLDER_ID", "shared-root")
        caps = double(can_delete: false, can_trash: false)
        allow(drive_service).to receive(:get_file)
          .and_return(double(capabilities: caps, parents: ["shared-root"]))
        allow(drive_service).to receive(:update_file)

        delete :destroy, params: { id: job.id }

        expect(drive_service).to have_received(:update_file)
          .with("file-abc", instance_of(Google::Apis::DriveV3::File),
                remove_parents: "shared-root", supports_all_drives: true, fields: "id")
        expect(response).to redirect_to(jobs_path)
      end

      it "redirects with 'Job delete failed' when Drive cannot delete, trash, or remove the file" do
        stub_const("FilesController::FOLDER_ID", "shared-root")
        caps = double(can_delete: false, can_trash: false)
        allow(drive_service).to receive(:get_file)
          .and_return(double(capabilities: caps, parents: ["other-folder"]))

        delete :destroy, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to include("Job delete failed")
      end

      it "skips a 404 error and still completes the deletion" do
        error = Google::Apis::ClientError.new("not found", status_code: 404)
        allow(drive_service).to receive(:get_file).and_raise(error)

        delete :destroy, params: { id: job.id }

        expect(response).to redirect_to(jobs_path)
      end

      it "redirects with 'Drive cleanup failed' on a non-404 Drive error" do
        error = Google::Apis::ClientError.new("Permission denied", status_code: 403)
        allow(drive_service).to receive(:get_file).and_raise(error)

        delete :destroy, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to include("Drive cleanup failed")
      end
    end
  end

  # ── validate_output_file! ─────────────────────────────────────────────────
  describe "POST #upload_output (validate_output_file! paths)" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user,
             title: "Validate Job", description: "Desc", status: :assigned)
    end

    before { sign_in operator_user }

    it "redirects with alert when the file has a non-pdf extension" do
      txt_tempfile = Tempfile.new(["report", ".txt"])
      txt_tempfile.write("content")
      txt_tempfile.rewind
      txt_file = Rack::Test::UploadedFile.new(txt_tempfile.path, "text/plain")

      post :upload_output, params: { id: job.id, output_file: txt_file }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:alert]).to include(".pdf extension")
    end

    it "redirects with alert when the file exceeds the 1 GB size limit" do
      stub_const("JobsController::MAX_FILE_SIZE_BYTES", 0)
      pdf_tempfile = Tempfile.new(["report", ".pdf"])
      pdf_tempfile.write("PDF content")
      pdf_tempfile.rewind
      pdf_file = Rack::Test::UploadedFile.new(pdf_tempfile.path, "application/pdf")

      post :upload_output, params: { id: job.id, output_file: pdf_file }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:alert]).to include("1 GB size limit")
    end
  end

  # ── attach_uploaded_file internals (ensure_drive_folder! / move_file_to_folder!) ──
  describe "attach_uploaded_file internals" do
    let(:drive_service) { double("drive_service") }
    let(:draft_job) do
      j = create(:job, client: client_user, operator: nil,
                 title: "Draft", description: "Desc", status: :draft)
      create(:image_file, job: j,
             file_path: "https://drive.google.com/pdf",
             file_type: '{"slot":"1","file_id":"pdf-id"}')
      create(:image_file, job: j,
             file_path: "https://drive.google.com/dcm",
             file_type: '{"slot":"2","file_id":"dcm-id"}')
      j
    end

    before do
      sign_in client_user
      allow(controller).to receive(:build_drive_service).and_return(drive_service)
    end

    context "ensure_drive_folder!" do
      it "creates a Drive folder when the job has no google_drive_folder_id" do
        # Test ensure_drive_folder! directly to avoid attach_uploaded_file stub ordering issues
        job = create(:job, client: client_user, operator: nil,
                     title: "Test", description: "Desc", status: :pending,
                     google_drive_folder_id: nil)
        folder = double("folder", id: "new-folder-id")
        allow(drive_service).to receive(:create_file).and_return(folder)

        result = controller.send(:ensure_drive_folder!, job, drive_service)

        expect(result).to eq("new-folder-id")
        expect(job.reload.google_drive_folder_id).to eq("new-folder-id")
      end

      it "reuses the existing folder_id without creating a new folder" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        draft_job.update_column(:google_drive_folder_id, "existing-folder-id")
        allow(drive_service).to receive(:create_file)
        allow(drive_service).to receive(:get_file)
          .and_return(double(parents: ["existing-folder-id"]))

        uploaded_json = JSON.generate([
          { slot: 1, file_id: "pdf-id",
            file_url: "https://example.com/pdf", file_type: "application/pdf" }
        ])
        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

        expect(drive_service).not_to have_received(:create_file)
      end
    end

    context "move_file_to_folder!" do
      before { draft_job.update_column(:google_drive_folder_id, "dest-folder-id") }

      it "skips the Drive update when the file is already in the destination folder" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        allow(drive_service).to receive(:update_file)
        allow(drive_service).to receive(:get_file)
          .and_return(double(parents: ["dest-folder-id"]))

        uploaded_json = JSON.generate([
          { slot: 1, file_id: "pdf-id",
            file_url: "https://example.com/pdf", file_type: "application/pdf" }
        ])
        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

        expect(drive_service).not_to have_received(:update_file)
      end

      it "calls update_file to move the file when it is not yet in the destination folder" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        allow(drive_service).to receive(:get_file)
          .and_return(double(parents: ["other-folder"]))
        allow(drive_service).to receive(:update_file)

        uploaded_json = JSON.generate([
          { slot: 1, file_id: "pdf-id",
            file_url: "https://example.com/pdf", file_type: "application/pdf" }
        ])
        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

        expect(drive_service).to have_received(:update_file)
          .with("pdf-id", instance_of(Google::Apis::DriveV3::File),
                hash_including(add_parents: "dest-folder-id"))
      end

      it "moves each individual file in a slot-2 DICOM array" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        allow(drive_service).to receive(:get_file)
          .and_return(double(parents: ["other-folder"]))
        allow(drive_service).to receive(:update_file)

        uploaded_json = JSON.generate([{
          slot: 2, file_id: nil, file_url: nil, file_type: "application/dicom",
          files: [
            { file_id: "dcm1", file_url: "https://example.com/dcm1",
              file_type: "application/dicom", file_name: "scan1.dcm", relative_path: nil },
            { file_id: "dcm2", file_url: "https://example.com/dcm2",
              file_type: "application/dicom", file_name: "scan2.dcm", relative_path: nil }
          ]
        }])
        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

        expect(drive_service).to have_received(:update_file).twice
      end
    end

    context "error handling" do
      it "rescues Google::Apis::Error and still completes the action" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        draft_job.update_column(:google_drive_folder_id, "dest-folder-id")
        allow(drive_service).to receive(:get_file)
          .and_raise(Google::Apis::Error.new("API error"))

        uploaded_json = JSON.generate([
          { slot: 1, file_id: "pdf-id",
            file_url: "https://example.com/pdf", file_type: "application/pdf" }
        ])
        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

        expect(response).to redirect_to(job_path(draft_job))
        expect(flash[:notice]).to eq("Job submitted successfully.")
      end

      it "rescues JSON::ParserError and still completes the action" do
        expect(controller).to receive(:attach_uploaded_file).and_call_original

        patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: "{invalid" }

        expect(response).to redirect_to(job_path(draft_job))
        expect(flash[:notice]).to eq("Job submitted successfully.")
      end
    end

    it "reaches the placeholder block when fewer than 2 files are uploaded" do
      expect(controller).to receive(:attach_uploaded_file).and_call_original

      draft_job.update_column(:google_drive_folder_id, "dest-folder-id")
      allow(drive_service).to receive(:get_file)
        .and_return(double(parents: ["other-folder"]))
      allow(drive_service).to receive(:update_file)

      # Only 1 uploaded file → uploaded_files.length < 2 → placeholder block is evaluated
      uploaded_json = JSON.generate([
        { slot: 1, file_id: "pdf-id",
          file_url: "https://example.com/pdf", file_type: "application/pdf" }
      ])
      patch :submit_draft, params: { id: draft_job.id, uploaded_files_json: uploaded_json }

      expect(response).to redirect_to(job_path(draft_job))
    end
  end

  # ── build_drive_service internals ──────────────────────────────────────────
  describe "private method #build_drive_service" do
    it "initialises DriveService with service-account credentials" do
      drive_svc   = double("DriveService")
      client_opts = double("client_options")
      allow(client_opts).to receive(:application_name=)
      allow(drive_svc).to receive(:client_options).and_return(client_opts)
      allow(drive_svc).to receive(:authorization=)
      allow(Google::Apis::DriveV3::DriveService).to receive(:new).and_return(drive_svc)

      credentials = double("credentials")
      allow(credentials).to receive(:fetch_access_token!)
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds)
        .and_return(credentials)

      result = controller.send(:build_drive_service)

      expect(result).to eq(drive_svc)
      expect(credentials).to have_received(:fetch_access_token!)
      expect(drive_svc).to have_received(:authorization=).with(credentials)
    end
  end

  # ── upload_output drive-upload success path ────────────────────────────────
  describe "POST #upload_output (drive upload path)" do
    let(:job) do
      create(:job, client: client_user, operator: operator_user,
             title: "Upload Job", description: "Desc", status: :assigned)
    end

    before { sign_in operator_user }

    it "uploads the file to Drive, saves metadata, and redirects with notice" do
      pdf_tempfile = Tempfile.new(["report", ".pdf"])
      pdf_tempfile.write("PDF content")
      pdf_tempfile.rewind
      pdf_file = Rack::Test::UploadedFile.new(pdf_tempfile.path, "application/pdf")

      drive_svc = double("drive_service")
      allow(controller).to receive(:build_drive_service).and_return(drive_svc)

      uploaded_file_obj = double("uploaded_file",
                                 id: "file-id-123",
                                 web_view_link: "https://drive.google.com/view",
                                 web_content_link: nil)
      allow(drive_svc).to receive(:create_file).and_return(uploaded_file_obj)
      allow(UserMailer).to receive_message_chain(:send_report_uploaded_email, :deliver_later)

      post :upload_output, params: { id: job.id, output_file: pdf_file }

      expect(response).to redirect_to(job_path(job))
      expect(flash[:notice]).to eq("Output file uploaded.")
      expect(job.image_files.last.file_type).to include('"slot":"output"')
    end
  end
end