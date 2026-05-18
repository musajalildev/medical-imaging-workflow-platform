require 'rails_helper'

RSpec.describe "Job Status Management and History", type: :feature do
  let(:operator) { create(:user, role: :operator) }
  let(:client) { create(:user, role: :client) }
  let(:admin) { create(:user, role: :admin) }
  let(:job) { create(:job, status: :assigned, client: client, operator: operator,
                            title: "Status Test Job") }

  before do
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_completed_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_cancelled_email).and_return(double(deliver_later: true))
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
  end

  describe "Status update form" do
    context "as an operator" do
      before { login_as operator, scope: :user }

      it "shows status dropdown for assigned jobs" do
        visit job_path(job)
        
        expect(page).to have_select("job_status")
      end

      it "displays available status options" do
        visit job_path(job)
        
        select = page.find('select#job_status')
        options = select.all('option').map(&:text)
        
        expect(options).to include("In progress")
        expect(options).to include("Assigned")
        expect(options).to include("Custom")
      end
    end

    context "as a client" do
      before { login_as client, scope: :user }

      it "does not show status dropdown for clients" do
        visit job_path(job)
        
        expect(page).not_to have_select("job_status")
      end

      it "does not allow status updates" do
        visit job_path(job)
        
        expect(page).not_to have_button("Update status")
      end
    end

    context "as an admin" do
      before { login_as admin, scope: :user }

      it "shows status dropdown for admins" do
        visit job_path(job)
        
        expect(page).to have_select("job_status")
      end
    end
  end

  describe "Status history tracking" do
    before { login_as operator, scope: :user }

    it "records initial status creation as history" do
      job.reload
      status_histories = job.status_histories
      
      expect(status_histories).to be_a(ActiveRecord::Relation)
    end

    it "shows status change initiator in history" do
      create(:job_status_history, job: job, 
             old_status: "Assigned", new_status: "In progress",
             initiator: operator)
      
      visit job_path(job)
      
      expect(page).to have_content(operator.email)
    end

    it "shows timestamp for status changes" do
      status_change_time = 1.hour.ago
      create(:job_status_history, job: job, created_at: status_change_time,
             old_status: "Assigned", new_status: "In progress",
             initiator: operator)
      
      visit job_path(job)
      
      formatted_time = status_change_time.strftime("%Y/%m/%d, at %H:%M")
      expect(page).to have_content(formatted_time)
    end

    it "shows old and new status in history" do
      create(:job_status_history, job: job,
             old_status: "Assigned", new_status: "In progress",
             initiator: operator)
      
      visit job_path(job)
      
      expect(page).to have_content("from Assigned to In progress")
    end
  end

  describe "Complete job workflow", js: true do
    before { login_as operator, scope: :user }

    it "marks job as complete" do
      visit job_path(job)
      
      accept_confirm do
        click_button "Mark as Complete"
      end
      
      expect(page).to have_content("Job was successfully completed")
      job.reload
      expect(job.status).to eq("complete")
    end
  end

  describe "Cancel job workflow", js: true do
    before { login_as operator, scope: :user }

    it "cancels an assigned job" do
      visit job_path(job)
      
      accept_confirm do
        click_button "Cancel Job"
      end
      
      expect(page).to have_content("Job was successfully cancelled")
      job.reload
      expect(job.status).to eq("cancelled")
    end

  end

  describe "Status display" do
    context "with standard status" do
      it "displays humanized status" do
        job.update(status: :in_progress)
        
        login_as client, scope: :user
        visit job_path(job)
        
        expect(page).to have_content("In progress")
      end
    end

    context "with custom status" do
      before do
        job.update(status: :custom, custom_status: "Waiting for Approval")
      end

      it "displays custom status instead of 'Custom'" do
        login_as client, scope: :user
        visit job_path(job)
        
        expect(page).to have_content("Waiting for Approval")
        expect(page).not_to have_content("Custom")
      end

      it "displays custom status in status history" do
        create(:job_status_history, job: job,
               old_status: "Assigned", new_status: "Waiting for Approval",
               initiator: operator)
        
        login_as operator, scope: :user
        visit job_path(job)
        
        expect(page).to have_content("Waiting for Approval")
      end
    end
  end

  describe "Status transition validation", js: true do
    before { login_as operator, scope: :user }

    it "allows transitioning from assigned to in_progress" do
      visit job_path(job)
      
      select "In progress", from: "job_status"
      click_button "Update status"
      
      expect(page).to have_content("Job was successfully updated")
    end
  end
end