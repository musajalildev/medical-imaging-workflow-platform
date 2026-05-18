require "rails_helper"

RSpec.describe PagesController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(UserMailer).to receive_message_chain(:with, :send_sign_up_email, :deliver_later).and_return(true)
    Rails.cache.clear
  end

  describe "GET #sign_up" do
    it "is successful" do
      get :sign_up
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
      user = double("User", email: "client@example.com")
      allow(controller).to receive(:current_user).and_return(user)

      post :send_sign_up_email, params: { comment: "Please approve" }

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:alert]).to eq("Please select a role.")
    end

    it "redirects with an alert when the email was already sent recently" do
      user = double("User", email: "client@example.com")
      allow(controller).to receive(:current_user).and_return(user)
      allow(Rails.cache).to receive(:read).and_return(true)

      post :send_sign_up_email, params: { role_selection: "client", comment: "Please approve" }

      expect(response).to redirect_to(sign_up_path)
      expect(flash[:alert]).to match(/only send one sign-up email per week/i)
    end

    it "sends the email when the role is present and the cache is empty" do
      user = double("User", email: "client@example.com")
      allow(controller).to receive(:current_user).and_return(user)
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
end