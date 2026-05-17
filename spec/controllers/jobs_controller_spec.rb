require "rails_helper"

RSpec.describe JobsController, type: :controller do
  describe "before_action :check_client_role" do
    let(:client_user) { create(:user, role: :client) }
    let(:operator_user) { create(:user, role: :operator) }
    let(:admin_user) { create(:user, role: :admin) }

    before do
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:dev_auto_login).and_return(true)
    end

    def stub_client_access(user)
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_ability).and_return(Ability.new(user))
      allow(controller).to receive(:authorize!).and_return(true)
    end

    describe "GET #new" do
      context "when user is a client" do
        before { stub_client_access(client_user) }

        it "allows access" do
          get :new
          expect(response).to have_http_status(:success)
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "redirects to jobs_path with alert" do
          get :new
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "redirects to jobs_path with alert" do
          get :new
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end

      context "when user is not authenticated" do
        before { allow(controller).to receive(:current_user).and_return(nil) }

        it "redirects to jobs_path with alert" do
          get :new
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end
    end

    describe "GET #edit" do
      let(:job) { create(:job, client: client_user) }


      context "when user is a client" do
        before { stub_client_access(client_user) }

        it "allows access" do
          get :edit, params: { id: job.id }
          expect(response).to have_http_status(:success)
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "redirects to jobs_path with alert" do
          get :edit, params: { id: job.id }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "redirects to jobs_path with alert" do
          get :edit, params: { id: job.id }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end
    end

    describe "POST #create" do
      context "when user is a client" do
        before do
          stub_client_access(client_user)
          allow(controller).to receive(:attach_uploaded_file)
        end

        it "runs without error" do
          post :create, params: {
            job: {
              title: "Test Job",
              description: "Test Description"
            },
            uploaded_files_json: "[]"
          }
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "redirects to jobs_path with alert" do
          post :create, params: {
            job: {
              title: "Test Job",
              description: "Test Description",
              client_id: client_user.id,
              operator_id: operator_user.id,
              status: "pending"
            },
            uploaded_files_json: "[]"
          }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "redirects to jobs_path with alert" do
          post :create, params: {
            job: {
              title: "Test Job",
              description: "Test Description",
              client_id: client_user.id,
              operator_id: operator_user.id,
              status: "pending"
            },
            uploaded_files_json: "[]"
          }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end
    end


    describe "PATCH #update" do
      let(:job) { create(:job, client: client_user) }


      context "when user is a client" do
        before { stub_client_access(client_user) }

        it "allows job update" do
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
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "redirects to jobs_path with alert" do
          patch :update, params: {
            id: job.id,
            job: { title: "Updated Title" },
            uploaded_files_json: "[]"
          }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "redirects to jobs_path with alert" do
          patch :update, params: {
            id: job.id,
            job: {
              title: "Updated Title"
            },
            uploaded_files_json: "[]"
          }
          expect(response).to redirect_to(jobs_path)
          expect(flash[:alert]).to match(/Only clients can create or edit jobs/)
        end
      end
    end

    describe "PATCH #self_assign" do
      let(:client_owner) { create(:user, role: :client) }
      let(:unassigned_job) { create(:job, client: client_owner, operator: nil, status: :pending) }

      context "when user is an operator" do
        before do
          allow(controller).to receive(:current_user).and_return(operator_user)
          allow(controller).to receive(:current_ability).and_return(Ability.new(operator_user))
          allow(controller).to receive(:authorize!).and_return(true)
        end

        it "assigns the operator to the job" do
          patch :self_assign, params: { id: unassigned_job.id }

          unassigned_job.reload
          expect(unassigned_job.operator_id).to eq(operator_user.id)
          expect(unassigned_job.status).to eq("assigned")
          expect(response).to redirect_to(jobs_path(tab: "unassigned"))
          expect(flash[:notice]).to match(/Job assigned to you/)
        end

        it "does not reassign an already assigned job" do
          already_assigned = create(:job, client: client_owner, operator: create(:user, role: :operator), status: :assigned)

          patch :self_assign, params: { id: already_assigned.id }

          expect(response).to redirect_to(jobs_path(tab: "unassigned"))
          expect(flash[:alert]).to match(/Job is already assigned/)
        end
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

      context "when user is a client" do
        before do
          allow(controller).to receive(:current_user).and_return(client_user)
          allow(controller).to receive(:current_ability).and_return(Ability.new(client_user))
        end

        it "shows active jobs by default" do
          get :index

          expect(controller.instance_variable_get(:@tab)).to eq("active")
          expect(controller.instance_variable_get(:@jobs)).to include(client_active_job)
          expect(controller.instance_variable_get(:@jobs)).not_to include(client_draft_job)
        end

        it "shows drafts when tab is drafts" do
          get :index, params: { tab: "drafts" }

          expect(controller.instance_variable_get(:@tab)).to eq("drafts")
          expect(controller.instance_variable_get(:@jobs)).to include(client_draft_job)
        end

        it "searches by title" do
          matched = create(:job, client: client_user, title: "Search Match", description: "Desc", status: :pending)
          create(:job, client: client_user, title: "Other Job", description: "Desc", status: :pending)

          get :index, params: { search: "Search", search_by: "title" }

          expect(controller.instance_variable_get(:@jobs)).to include(matched)
        end
      end

      context "when user is an operator" do
        before do
          allow(controller).to receive(:current_user).and_return(operator_user)
          allow(controller).to receive(:current_ability).and_return(Ability.new(operator_user))
        end

        it "shows assigned jobs by default" do
          get :index

          expect(controller.instance_variable_get(:@tab)).to eq("assigned")
          expect(controller.instance_variable_get(:@jobs)).to include(operator_assigned_job)
        end

        it "shows unassigned jobs when tab is unassigned" do
          unassigned_job = create(:job, client: client_user, title: "Unassigned", description: "Desc", operator: nil, status: :pending)

          get :index, params: { tab: "unassigned" }

          expect(controller.instance_variable_get(:@tab)).to eq("unassigned")
          expect(controller.instance_variable_get(:@jobs)).to include(unassigned_job)
        end
      end
    end

    describe "POST #create" do
      context "when user is a client" do
        before do
          stub_client_access(client_user)
          allow(controller).to receive(:attach_uploaded_file)
          allow(UserMailer).to receive_message_chain(:send_new_job_email, :deliver_later)
        end

        it "creates a draft job" do
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

        it "creates a normal job when two uploaded files are provided" do
          expect do
            post :create, params: {
              job: {
                title: "Test Job",
                description: "Test Description"
              },
              uploaded_files_json: [
                { file_id: "file-1", file_type: "application/pdf" },
                { file_id: "file-2", file_type: "application/dicom" }
              ].to_json
            }
          end.to change(Job, :count).by(1)

          expect(Job.last.client_id).to eq(client_user.id)
          expect(Job.last.status).to eq("pending")
        end
      end
    end

    describe "PATCH #update" do
      let(:job) { create(:job, client: client_user, title: "Original", description: "Original description", status: :pending) }

      context "when user is a client" do
        before { stub_client_access(client_user) }

        it "updates the job" do
          allow(controller).to receive(:attach_uploaded_file)

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
          expect(response).to redirect_to(job_path(job))
        end

        it "renders edit when the update is invalid" do
          allow(controller).to receive(:attach_uploaded_file)

          patch :update, params: {
            id: job.id,
            job: {
              title: ""
            },
            uploaded_files_json: "[]"
          }

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe "PATCH #update_status" do
      let(:job) do
        create(:job, client: client_user, operator: operator_user, title: "Status Job", description: "Desc", status: :pending)
      end

      before do
        allow(controller).to receive(:current_user).and_return(operator_user)
        allow(controller).to receive(:current_ability).and_return(Ability.new(operator_user))
        allow(UserMailer).to receive_message_chain(:send_job_status_change_email, :deliver_later)
      end

      it "updates the status and creates history when status changes" do
        expect do
          patch :update_status, params: {
            id: job.id,
            job: {
              status: "assigned",
              custom_status: ""
            }
          }
        end.to change(JobStatusHistory, :count).by(1)

        job.reload
        expect(job.status).to eq("assigned")
      end

      it "does not create history when status stays the same" do
        expect do
          patch :update_status, params: {
            id: job.id,
            job: {
              status: "pending",
              custom_status: ""
            }
          }
        end.not_to change(JobStatusHistory, :count)

        expect(response).to redirect_to(job_path(job))
      end
    end

    describe "PATCH #complete_job" do
      let(:job) do
        create(:job, client: client_user, operator: operator_user, title: "Complete Job", description: "Desc", status: :assigned)
      end

      before do
        allow(controller).to receive(:current_user).and_return(operator_user)
        allow(controller).to receive(:current_ability).and_return(Ability.new(operator_user))
        allow(UserMailer).to receive_message_chain(:send_job_completed_email, :deliver_later)
      end

      it "marks the job complete" do
        expect do
          patch :complete_job, params: { id: job.id }
        end.to change(JobStatusHistory, :count).by(1)

        job.reload
        expect(job.status).to eq("complete")
        expect(response).to redirect_to(job_path(job))
      end
    end

    describe "PATCH #cancel_job" do
      let(:job) do
        create(:job, client: client_user, operator: operator_user, title: "Cancelable Job", description: "Desc", status: :assigned)
      end

      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
        allow(controller).to receive(:current_ability).and_return(Ability.new(admin_user))
        allow(UserMailer).to receive_message_chain(:send_job_cancelled_email, :deliver_later)
      end

      it "cancels a non-draft job" do
        expect do
          patch :cancel_job, params: { id: job.id }
        end.to change(JobStatusHistory, :count).by(1)

        job.reload
        expect(job.status).to eq("cancelled")
      end

      it "deletes a draft job" do
        draft_job = create(:job, client: client_user, title: "Draft Delete", description: nil, status: :draft)

        patch :cancel_job, params: { id: draft_job.id }

        expect(response).to redirect_to(jobs_path(tab: "drafts"))
        expect(Job.exists?(draft_job.id)).to be(false)
      end
    end

    describe "PATCH #submit_draft" do
      let(:draft_job) do
        create(:job, client: client_user, title: "Draft Job", description: nil, status: :draft)
      end

      before do
        stub_client_access(client_user)
        allow(controller).to receive(:attach_uploaded_file)
      end

      it "rejects jobs that are not drafts" do
        non_draft_job = create(:job, client: client_user, title: "Live Job", description: "Desc", status: :pending)

        patch :submit_draft, params: { id: non_draft_job.id }

        expect(response).to redirect_to(job_path(non_draft_job))
        expect(flash[:alert]).to eq("This job is not a draft.")
      end

      it "rejects draft jobs without input files" do
        patch :submit_draft, params: { id: draft_job.id }

        expect(response).to redirect_to(job_path(draft_job))
        expect(flash[:alert]).to match(/Both input files/)
      end
    end

        describe "DELETE #destroy" do
      let(:job) { create(:job, client: client_user, title: "Destroy Job", description: "Desc", status: :pending) }

      before do
        allow(controller).to receive(:current_user).and_return(admin_user)
        allow(controller).to receive(:current_ability).and_return(Ability.new(admin_user))
      end

      it "redirects to jobs_path when drive cleanup succeeds" do
        allow(controller).to receive(:purge_job_files_from_drive).and_return(nil)
        allow_any_instance_of(Job).to receive(:destroy!).and_return(true)

        delete :destroy, params: { id: job.id }

        expect(response).to redirect_to(jobs_path)
      end

      it "redirects back to the job when drive cleanup fails" do
        allow(controller).to receive(:purge_job_files_from_drive).and_return("drive failed")

        delete :destroy, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to match(/Drive cleanup failed/)
      end
    end

    describe "POST #upload_output" do
      let(:job) do
        create(:job, client: client_user, operator: operator_user, title: "Output Job", description: "Desc", status: :pending)
      end

      it "rejects non-operators" do
        allow(controller).to receive(:current_user).and_return(client_user)

        post :upload_output, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to eq("Only operators can upload output files.")
      end

      it "rejects completed jobs" do
        allow(controller).to receive(:current_user).and_return(operator_user)

        job.update!(status: :complete)

        post :upload_output, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to eq("Completed jobs cannot accept report uploads.")
      end

      it "rejects missing file uploads" do
        allow(controller).to receive(:current_user).and_return(operator_user)

        post :upload_output, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to eq("Please select an output file.")
      end
    end

    describe "POST #upload_output" do
      let(:job) { create(:job, client: client_user, operator: operator_user, status: :complete) }

      before do
        allow(controller).to receive(:current_user).and_return(operator_user)
        allow(controller).to receive(:current_ability).and_return(Ability.new(operator_user))
        allow(controller).to receive(:authorize!).and_return(true)
      end

      it "rejects uploads for completed jobs" do
        post :upload_output, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to match(/Completed jobs cannot accept report uploads/)
      end
    end
  end
end