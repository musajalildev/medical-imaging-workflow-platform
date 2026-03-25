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
      let(:job) { create(:job) }

      context "when user is a client" do
        before { allow(controller).to receive(:current_user).and_return(client_user) }

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
        before { allow(controller).to receive(:current_user).and_return(client_user) }

        it "allows job creation" do
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
          }.to change(Job, :count).by(1)
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
      let(:job) { create(:job) }

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
      end

      context "when user is an operator" do
        before { allow(controller).to receive(:current_user).and_return(operator_user) }

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
  end
end
