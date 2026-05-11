require "rails_helper"

RSpec.describe "Navigation", type: :system do
  before do
    driven_by(:rack_test)
  end

  it "loads the home page" do
    visit root_path
    expect(page.status_code).to eq(200)
  end

  it "loads the jobs index page" do
    visit jobs_path
    expect(page.status_code).to eq(200)
  end

  it "loads the jobs index page with the drafts tab" do
    visit jobs_path(tab: "drafts")
    expect(page.status_code).to eq(200)
  end

  it "loads a job show page" do
    job = create(:job, title: "System Test Job", description: "System Test Description")

    visit job_path(job)

    expect(page.status_code).to eq(200)
  end
end