require "rails_helper"

RSpec.describe UsersController, type: :controller do
  let(:admin) { create(:user, role: :admin) }

  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(admin)
    allow(controller).to receive(:current_ability).and_return(Ability.new(admin))
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe "GET #index" do
    it "returns success" do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET #edit" do
    it "returns success" do
      user = create(:user)
      get :edit, params: { id: user.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH #update" do
    it "updates the user role and redirects" do
      user = create(:user, role: :client)

      patch :update, params: { id: user.id, user: { role: "operator" } }

      expect(response).to redirect_to(users_path)
    end
  end
end