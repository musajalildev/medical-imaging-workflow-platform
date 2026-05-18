# spec/controllers/reports_controller_spec.rb
require "rails_helper"

RSpec.describe ReportsController, type: :controller do
  before do
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:dev_auto_login).and_return(true)
    allow(controller).to receive(:redirect_to).and_return(true)
    allow(controller).to receive(:render).and_return(true)

    report = double("Report", save: true, update: true, destroy!: true)

    stub_const("Report", Class.new)

    Report.define_singleton_method(:all) do
      []
    end

    Report.define_singleton_method(:find) do |_id|
      report
    end

    Report.define_singleton_method(:new) do |_attrs = {}|
      report
    end
  end

  describe "GET #index" do
    it "assigns reports" do
      get :index
      expect(controller.instance_variable_get(:@reports)).to eq([])
    end
  end

  describe "GET #show" do
    it "assigns a report" do
      get :show, params: { id: 1 }
      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end

  describe "GET #new" do
    it "assigns a new report" do
      get :new
      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end

  describe "GET #edit" do
    it "assigns a report" do
      get :edit, params: { id: 1 }
      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end

  describe "POST #create" do
    it "runs without error" do
      post :create, params: {
        report: {
          job_id: 1,
          file_path: "test/report.pdf"
        }
      }

      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end

  describe "PATCH #update" do
    it "runs without error" do
      patch :update, params: {
        id: 1,
        report: {
          job_id: 1,
          file_path: "updated/report.pdf"
        }
      }

      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end

  describe "DELETE #destroy" do
    it "runs without error" do
      delete :destroy, params: { id: 1 }

      expect(controller.instance_variable_get(:@report)).not_to be_nil
    end
  end
end