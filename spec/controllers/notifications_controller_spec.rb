# spec/controllers/notifications_controller_spec.rb
require "rails_helper"

RSpec.describe NotificationsController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    notification = double("Notification", save: true, update: true, destroy!: true)

    stub_const("Notification", Class.new)

    Notification.define_singleton_method(:all) do
      []
    end

    Notification.define_singleton_method(:find) do |_id|
      notification
    end

    Notification.define_singleton_method(:new) do |_attrs = {}|
      notification
    end
  end

  describe "GET #index" do
    it "assigns notifications" do
      get :index
      expect(controller.instance_variable_get(:@notifications)).to eq([])
    end
  end

  describe "GET #show" do
    it "assigns a notification" do
      get :show, params: { id: 1 }
      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end

  describe "GET #new" do
    it "assigns a new notification" do
      get :new
      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end

  describe "GET #edit" do
    it "assigns a notification" do
      get :edit, params: { id: 1 }
      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        notification: {
          user_id: 1,
          body: "Test body",
          is_read: false
        }
      }

      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        notification: {
          user_id: 1,
          body: "Updated body",
          is_read: true
        }
      }

      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@notification)).not_to be_nil
    end
  end
end