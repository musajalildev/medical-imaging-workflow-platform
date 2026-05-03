require "rails_helper"

RSpec.describe JobsController, type: :controller do
  describe "before_action :check_client_role" do
    before do
      allow(controller).to receive(:authenticate_user!).and_return(true)
      allow(controller).to receive(:dev_auto_login).and_return(true)
    end

    let(:client_user) { create(:user, role: :client) }
    let(:operator_user) { create(:user, role: :operator) }
    let(:admin_user) { create(:user, role: :admin) }

    describe "GET #new" do
      context "when user is a client" do
        before { allow(controller).to receive(:current_user).and_return(client_user) }

        it "allows access" do
          get :new
          expect(response).to have_http_status(:success)
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "Raises AccessDenied" do
          expect { get :new }.to raise_error(CanCan::AccessDenied)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "Raises AccessDenied" do
          expect { get :new }.to raise_error(CanCan::AccessDenied)
        end
      end

      context "when user is not authenticated" do
        before { allow(controller).to receive(:current_user).and_return(nil) }

        it "Raises AccessDenied" do
          expect { get :new }.to raise_error(CanCan::AccessDenied)
        end
      end
    end

    describe "GET #edit" do
      let(:job) { create(:job, client: client_user) }


      context "when user is a client" do
        before { allow(controller).to receive(:current_user).and_return(client_user) }

        it "allows access" do
          get :edit, params: { id: job.id }
          expect(response).to have_http_status(:success)
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "Raises AccessDenied" do
          expect {
            get :edit, params: { id: job.id }
          }.to raise_error(CanCan::AccessDenied)
end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "Raises AccessDenied" do
          get :edit, params: { id: job.id }
          expect { get :new }.to raise_error(CanCan::AccessDenied)
       end
      end
    end

    describe "POST #create" do
      context "when user is a client" do
        before do
          allow(controller).to receive(:current_user).and_return(client_user)
          allow(controller).to receive(:attach_uploaded_file)
        end

        it "allows job creation" do
          expect {
            post :create, params: {
              job: {
                title: "Test Job",
                description: "Test Description",
                operator_id: operator_user.id,
                status: "pending"
              },
              uploaded_files_json: "[]"
            }
          }.to change(Job, :count).by(1)

          expect(Job.last.client_id).to eq(client_user.id)
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "raises AccessDenied" do
          expect {
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
          }.to raise_error(CanCan::AccessDenied)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "raises AccessDenied" do
          expect {
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
          }.to raise_error(CanCan::AccessDenied)
        end
      end
    end


    describe "PATCH #update" do
      let(:job) { create(:job, client: client_user) }


      context "when user is a client" do
        before { allow(controller).to receive(:current_user).and_return(client_user) }

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

        it "does not allow client to change status through update" do
          job.update!(client: client_user, status: :pending)

          patch :update, params: {
            id: job.id,
            job: {
              title: "Updated Title",
              status: "complete"
            },
            uploaded_files_json: "[]"
          }

          job.reload
          expect(job.status).to eq("pending")
        end
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

        it "Raises AccessDenied" do
          expect {patch :update, params: {
            id: job.id,
            job: {
              title: "Updated Title"
            },
            uploaded_files_json: "[]"
          }
        }.to raise_error(CanCan::AccessDenied)
        end
      end

      context "when user is an admin" do
        before { allow(controller).to receive(:current_user).and_return(admin_user) }

        it "Raises AccessDenied" do
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
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

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

    describe "POST #upload_output" do
      let(:job) { create(:job, client: client_user, operator: operator_user, status: :complete) }

      before { allow(controller).to receive(:current_user).and_return(operator_user) }

      it "rejects uploads for completed jobs" do
        post :upload_output, params: { id: job.id }

        expect(response).to redirect_to(job_path(job))
        expect(flash[:alert]).to match(/Completed jobs cannot accept report uploads/)
      end
    end
  end
end
