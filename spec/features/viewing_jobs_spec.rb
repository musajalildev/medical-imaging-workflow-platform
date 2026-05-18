require 'rails_helper'


RSpec.describe "Viewing Jobs", type: :feature do

  let(:job) { create(:job) }
  let(:client) { job.client }
  let(:operator) { job.operator }
  let(:admin) { create(:user, :admin) }

  before do
    allow(UserMailer).to receive(:send_job_cancelled_email)
      .and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_completed_email)
      .and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_status_change_email)
      .and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_accepted_email)
      .and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_new_job_email)
      .and_return(double(deliver_later: true))
  end

  # role based visibilty of the job details and emails

  specify "a client can view their job details" do
    login_as client, scope: :user
    visit job_path(job)
    expect(page).to have_content(job.title)
    # other details added to the page will also have to be checked here
  end

  specify "an operator can view job details" do
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).to have_content(job.title)
    # other details added to the page will also have to be checked here
  end

  specify "a client can see the operator email if an operator is assigned to the job" do
    login_as client, scope: :user
    visit job_path(job)
    expect(page).to have_content(operator.email)
  end

  specify "an operator can see the client email" do
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).to have_content(client.email)
  end

  specify "a client cannot see the client email" do
    login_as client, scope: :user
    visit job_path(job)
    within(".job-meta-list") do
      expect(page).not_to have_content(client.email)
    end
  end

  specify "an operator cannot see the operator email" do
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).not_to have_content(operator.email)
  end

  specify "an admin can view job details" do
    login_as admin, scope: :user
    visit job_path(job)
    expect(page).to have_content(job.title)
  end

  specify "an admin can see both client and operator emails" do
    login_as admin, scope: :user
    visit job_path(job)
    expect(page).to have_content(client.email)
    expect(page).to have_content(operator.email)
  end

  # status display

  specify "a user can see the job status" do
    login_as client, scope: :user
    visit job_path(job)
    expect(page).to have_content(job.get_status_for_display)
  end

  # status history display

  specify "a user can see the formatted status history for a job" do
    status_history = create(:job_status_history, job: job)
    login_as client, scope: :user
    visit job_path(job)
    expect(page).to have_content(status_history.old_status.humanize)
    expect(page).to have_content(status_history.new_status.humanize)
    expect(page).to have_content(status_history.initiator.email)
    expect(page).to have_content(status_history.created_at.strftime("%Y/%m/%d, at %H:%M"))
  end

  specify "the status history is displayed in reverse chronological order" do
    older_status_history = create(:job_status_history, job: job, created_at: 2.days.ago)
    newer_status_history = create(:job_status_history, job: job, created_at: 1.day.ago)
    login_as client, scope: :user
    visit job_path(job)
    expect(page.body.index(newer_status_history.created_at.strftime("%Y/%m/%d, at %H:%M"))).to be < page.body.index(older_status_history.created_at.strftime("%Y/%m/%d, at %H:%M"))
  end

  specify "a new status update is added to the history when the job status is changed", js: true do
    login_as operator, scope: :user
    visit job_path(job)

    old_status = job.get_status_for_display

    select "In progress", from: "job_status"
    click_button "Update status"

    expect(page).to have_content(operator.email)
    expect(page).to have_content("from #{old_status} to In progress", wait: 5)
  end

  # status updates (form) - only available for operators and admins

  specify "an operator or admin can see the status dropdown when a job is not complete or cancelled" do
    login_as operator, scope: :user
    visit job_path(job) # by default the job created by the factory is in the "assigned" status, so the dropdown should be visible

    expect(page).to have_select("job_status", options: ["Pending", "Assigned", "In progress", "Custom"])
  end

  specify "an operator or admin can update the job status using the dropdown", js: true do
    login_as operator, scope: :user
    visit job_path(job)

    select "In progress", from: "job_status"
    click_button "Update status"
    expect(page).to have_content("In progress")
  end

  specify "marking a job as complete hides the dropdown", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    accept_confirm do
      click_button "Mark as Complete"
    end
    expect(page).not_to have_select("Change status")
  end

  specify "cancelling a job hides the dropdown", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    accept_confirm do
      click_button "Cancel Job"
    end    
    expect(page).not_to have_select("Change status")
  end

  specify "the save changes button is hidden until a change is made to the status, then it is visible", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).not_to have_button("Update Status")
  
    select "In progress", from: "job_status"
    expect(page).to have_button("Update status")
  end

  specify "an operator or admin can enter a custom status when the dropdown is set to 'custom'", js: true do
    login_as operator, scope: :user
    visit job_path(job)
  
    select "Custom", from: "job_status"
    fill_in "Enter custom status", with: "Awaiting parts"
    click_button "Update status"
  
    expect(page).to have_content("Awaiting parts")
    expect(page).to have_content(operator.email)
    expect(page).to have_content("Awaiting parts")
    expect(job.reload.get_status_for_display).to eq("Awaiting parts")
  end

  specify "the custom status input is hidden when the dropdown is not set to 'custom'", js: true do
    login_as operator, scope: :user
    visit job_path(job)
  
    expect(page).not_to have_field("Enter custom status")
  
    select "In progress", from: "job_status"
    expect(page).not_to have_field("Enter custom status")
  
    select "Custom", from: "job_status"
    expect(page).to have_field("Enter custom status")
  end

  specify "a user cannot enter an empty custom status", js: true do
    login_as operator, scope: :user
    visit job_path(job)
  
    select "Custom", from: "job_status"
    fill_in "Enter custom status", with: ""
  
    expect(page).not_to have_button("Update status")
  end

  # restrictions on complete or cancelled jobs - only available for operators and admins

  specify "an operator or admin cannot see the status dropdown when a job is complete" do
    job.update!(status: :complete)
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).not_to have_select("Change status")
  end

  specify "an operator or admin cannot see the status dropdown when a job is cancelled" do
    job.update!(status: :cancelled)
    login_as operator, scope: :user
    visit job_path(job)
    expect(page).not_to have_select("Change status")
  end

  # complete / cancel actions - only available for operators and admins

  specify "an operator or admin can mark a job as complete", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    accept_confirm do
      click_button "Mark as Complete"
    end
    expect(page).to have_content("Complete")
  end

  specify "an operator or admin can cancel a job", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    accept_confirm do
      click_button "Cancel Job"
    end
    expect(page).to have_content("Cancelled")
  end

  specify "a comfirmation prompt is shown when marking a job as complete", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    
    accept_confirm("Are you sure you want to mark this job as complete? You will no longer be able to edit it.") do
      click_button "Mark as Complete"
    end
  end

  specify "a confirmation prompt is shown when cancelling a job", js: true do
    login_as operator, scope: :user
    visit job_path(job)
    
    accept_confirm("Are you sure you want to cancel this job? You will no longer be able to edit it.") do
      click_button "Cancel Job"
    end
  end
end