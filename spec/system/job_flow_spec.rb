require "rails_helper"

RSpec.describe "Job flow", type: :system do
  before do
    driven_by(:rack_test)
  end

  it "lets a client visit the jobs page" do
    user = create(:user, role: :client)

    login_as(user, scope: :user) if defined?(login_as)

    visit jobs_path

    expect(page).to have_content("Jobs")
  end
end