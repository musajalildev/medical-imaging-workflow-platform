require "rails_helper"

RSpec.describe PagesController, type: :controller do
  let(:unassigned_user) { create(:user, role: :unassigned, email: "user@example.com") }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(UserMailer).to receive_message_chain(:with, :send_sign_up_email, :deliver_later).and_return(true)
    allow(UserMailer).to receive_message_chain(:with, :send_help_email, :deliver_later).and_return(true)
    Rails.cache.clear
  end

  describe "GET #sign_up" do
    it "is successful when user is unassigned" do
      sign_in unassigned_user
      get :sign_up
      expect(response).to be_successful
    end

    it "rejects users with a role" do
      client = create(:user, role: :client)
      get :sign_up
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #help" do
    it "accepts clients" do
      client = create(:user, role: :client)
      sign_in client
      get :help
      expect(response).to be_successful
    end

    it "accepts operators" do
      operator = create(:user, role: :operator)
      sign_in operator
      get :help
      expect(response).to be_successful
    end
  end

  describe "GET #landing" do
    it "sets the job stats" do
      client = create(:user, role: :client)

      completed_job = create(:job, client: client, title: "Completed", description: "Desc", status: :complete)
      completed_job.update_columns(created_at: 2.days.ago, updated_at: Time.current)

      create(:job, client: client, title: "Cancelled", description: "Desc", status: :cancelled)
      create(:job, client: client, title: "Pending", description: "Desc", status: :pending)
      create(:job, client: client, title: "Assigned", description: "Desc", status: :assigned)
      create(:job, client: client, title: "In Progress", description: "Desc", status: :in_progress)

      get :landing

      expect(controller.instance_variable_get(:@total_jobs)).to eq(5)
      expect(controller.instance_variable_get(:@completed_jobs)).to eq(1)
      expect(controller.instance_variable_get(:@cancelled_jobs)).to eq(1)
      expect(controller.instance_variable_get(:@pending_jobs)).to eq(1)
      expect(controller.instance_variable_get(:@active_jobs)).to eq(2)
      expect(controller.instance_variable_get(:@avg_completion_time)).to eq(2.0)
      expect(controller.instance_variable_get(:@completion_rate)).to eq(50.0)
    end

    it "sets avg completion time to 0 when there are no completed jobs" do
      client = create(:user, role: :client)
      create(:job, client: client, title: "Pending", description: "Desc", status: :pending)

      get :landing

      expect(controller.instance_variable_get(:@completed_jobs)).to eq(0)
      expect(controller.instance_variable_get(:@avg_completion_time)).to eq(0)
      expect(controller.instance_variable_get(:@completion_rate)).to eq(0)
    end
  end

  describe "POST #send_sign_up_email" do
    it "redirects with an alert when role is missing" do
      allow(controller).to receive(:current_user).and_return(unassigned_user)

      post :send_sign_up_email, params: { comment: "Please approve" }

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:alert]).to eq("Please select a role.")
    end

    it "redirects with an alert when the email was already sent recently" do
      allow(controller).to receive(:current_user).and_return(unassigned_user)
      allow(Rails.cache).to receive(:read).and_return(true)

      post :send_sign_up_email, params: { role_selection: "client", comment: "Please approve" }

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:alert]).to match(/only send one sign-up email per week/i)
    end

    it "sends the email when the role is present and the cache is empty" do
      allow(controller).to receive(:current_user).and_return(unassigned_user)
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)

      post :send_sign_up_email, params: {
        role_selection: "client",
        comment: "Please approve"
      }

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:notice]).to eq("Sign up email sent successfully!")
    end
  end

  describe "POST #send_help_email" do
    let(:client) { create(:user, role: :client) }

    before do
      sign_in client
    end

    it "redirects with alert when issue is blank" do
      post :send_help_email, params: { issue_type: nil, expansion: "some expansion", job_id: nil }

      expect(response).to redirect_to(help_path)
      expect(flash[:alert]).to eq("Please select an issue.")
    end

    it "redirects with alert when issue is 'other' and no expansion is provided" do
      post :send_help_email, params: { issue_type: "Other", expansion: nil, job_id: nil }

      expect(response).to redirect_to(help_path)
      expect(flash[:alert]).to eq("Please provide an explanation of your issue.")
    end

    it "redirects with alert when there are no admins in the database to contact" do
      post :send_help_email, params: { issue_type: "Other", expansion: "some expansion", job_id: nil }

      expect(response).to redirect_to(help_path)
      expect(flash[:alert]).to eq("Sorry, there are no system administrators available to contact at this time.")
    end

    it "redirects with success message when everything is provided and there is an admin available" do
      admin = create(:user, role: :admin, email: "admin@example.com")

      post :send_help_email, params: { issue_type: "Other", expansion: "some expansion", job_id: nil }

      expect(response).to redirect_to(help_path)
      expect(flash[:notice]).to eq("Help request sent successfully, a system administrator will be in touch.")
    end
  end
end