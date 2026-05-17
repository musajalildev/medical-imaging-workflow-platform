# spec/controllers/application_controller_spec.rb
require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller(ApplicationController) do
    def index
      head :ok
    end

    def html_denied
      raise CanCan::AccessDenied
    end

    def json_denied
      request.format = :json
      raise CanCan::AccessDenied
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "html_denied" => "anonymous#html_denied"
      get "json_denied" => "anonymous#json_denied"
    end

    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
  end

  describe "response headers" do
    it "disables caching" do
      get :index

      expect(response.headers["Cache-Control"]).to eq("private, no-store")
      expect(response.headers["Pragma"]).to eq("no-cache")
      expect(response.headers["Expires"]).to eq("-1")
    end
  end

  describe "#after_sign_in_path_for" do
    it "returns sign_up_path for unassigned users" do
      user = double("User", unassigned?: true)

      expect(controller.send(:after_sign_in_path_for, user)).to eq(sign_up_path)
    end

    it "returns jobs_path for assigned users" do
      user = double("User", unassigned?: false)

      expect(controller.send(:after_sign_in_path_for, user)).to eq(jobs_path)
    end
  end

  describe "CanCan rescue_from" do
    it "redirects html access denied requests to root with an alert" do
      get :html_denied

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("You are not authorized to access this page.")
    end

    it "returns json access denied responses as forbidden" do
      get :json_denied, format: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)).to eq("error" => "Access denied")
    end
  end
end