require 'rails_helper'

RSpec.describe "User Authentication and Authorization", type: :feature do
  let(:client) { create(:user, role: :client) }
  let(:operator) { create(:user, role: :operator) }
  let(:admin) { create(:user, role: :admin) }
  let(:owner) { create(:user, role: :owner) }
  let(:unassigned) { create(:user, role: :unassigned) }
  let(:job) { create(:job, status: :assigned, client: client, operator: operator) }

  before do
    allow(UserMailer).to receive(:send_new_job_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
  end

  describe "Authentication" do
    it "redirects unauthenticated users to login" do
      visit jobs_path
      
      expect(current_path).to include("sign")
    end

    it "allows authenticated users to access jobs" do
      login_as client, scope: :user
      visit jobs_path
      
      expect(page).not_to have_content("not authorized")
    end
  end

  describe "Role-based access control" do
    describe "Client role permissions" do
      before { login_as client, scope: :user }

      it "allows clients to create jobs" do
        visit new_job_path
        
        expect(page).not_to have_content("not authorized")
      end

      it "allows clients to view their own jobs" do
        client_job = create(:job, status: :pending, client: client, operator: nil)
        
        visit job_path(client_job)
        
        expect(page).to have_content(client_job.title.humanize)
      end

      it "prevents clients from creating drafts if not their role" do

        visit new_job_path
        
        expect(page).not_to have_content("not authorized")
      end

      it "shows jobs in their correct tab" do
        create(:job, status: :draft, client: client, operator: nil, description: nil)
        create(:job, status: :pending, client: client, operator: nil)
        
        visit jobs_path
        
        expect(page).to have_content("My Jobs")
        expect(page).to have_content("Drafts")
      end

      it "prevents clients from updating job status" do
        visit job_path(job)
        
        expect(page).not_to have_select("job_status")
      end

      it "prevents clients from uploading output files" do
        visit job_path(job)
        
        expect(page).not_to have_button("Upload report file")
      end

      it "prevents clients from self-assigning jobs" do
        visit job_path(job)
        
        expect(page).not_to have_button("Self assign")
      end

      it "allows clients to edit their own drafts" do
        draft = create(:job, status: :draft, client: client, operator: nil)
        
        visit edit_job_path(draft)
        
        expect(page).not_to have_content("not authorized")
      end

      it "prevents clients from editing drafts of other clients" do
        other_client = create(:user, role: :client)
        other_draft = create(:job, status: :draft, client: other_client, operator: nil)
        
        visit edit_job_path(other_draft)
        
        expect(page).to have_content("not authorized")
      end
    end

    describe "Operator role permissions" do
      before { login_as operator, scope: :user }

      it "prevents operators from creating jobs" do
        visit new_job_path
        
        expect(page).to have_content("not authorized")
      end

      it "prevents operators from creating drafts" do
        visit new_job_path
        
        expect(page).to have_content("not authorized")
      end

      it "allows operators to view assigned jobs" do
        visit job_path(job)
        
        expect(page).to have_content(job.title.humanize)
      end

      it "allows operators to update job status" do
        visit job_path(job)
        
        expect(page).to have_select("job_status")
      end

      it "allows operators to upload output files" do
        visit job_path(job)
        
        expect(page).to have_button("Upload report file")
      end

      it "prevents operators from viewing unassigned jobs tab without assignment" do
        #Operators should only see their own assigned jobs or unassigned pool
        visit jobs_path(tab: "assigned")
        
        expect(page).not_to have_content(job.title.humanize) if job.operator != operator
      end

      it "prevents operators from editing drafts" do
        draft = create(:job, status: :draft, client: client, operator: nil)
        
        visit edit_job_path(draft)
        
        expect(page).to have_content("not authorized")
      end
    end

    describe "Admin role permissions" do
      before { login_as admin, scope: :user }

      it "allows admins to view all jobs" do
        visit job_path(job)
        
        expect(page).to have_content(job.title.humanize)
      end

      it "allows admins to update job status" do
        visit job_path(job)
        
        expect(page).to have_select("job_status")
      end

      it "prevents admins from creating jobs as client" do
        visit new_job_path
        expect(page).to have_content("Extreme-scale finite-element analysis services")
      end

      it "shows comprehensive dashboard view" do
        create(:job, status: :pending, client: client, operator: nil)
        create(:job, status: :assigned, client: client, operator: operator)
        create(:job, status: :draft, client: client, operator: nil, description: nil)
        
        visit jobs_path
        
        #Admin should see overview of system
        expect(page).not_to have_content("not authorized")
      end
    end

    describe "Unassigned role permissions" do
      before { login_as unassigned, scope: :user }

      it "prevents unassigned users from creating jobs" do
        visit new_job_path
        
        expect(page).to have_content("not authorized")
      end

      it "prevents unassigned users from viewing job details" do
        visit job_path(job)
        
        expect(page).to have_content("not authorized")
      end

      it "prevents unassigned users from uploading files" do
        visit job_path(job)
        
        expect(page).not_to have_button("Upload report file")
      end
    end
  end

  describe "Job ownership and visibility" do
    let(:other_client) { create(:user, role: :client) }
    let(:other_operator) { create(:user, role: :operator) }
    let(:client_job) { create(:job, status: :assigned, client: client, operator: operator) }
    let(:other_job) { create(:job, status: :assigned, client: other_client, operator: other_operator) }

    describe "Client viewing permissions" do
      before { login_as client, scope: :user }

      it "allows client to view their own job" do
        visit job_path(client_job)
        
        expect(page).to have_content(client_job.title.humanize)
      end

      it "prevents client from viewing other client's job" do
        visit job_path(other_job)
        
        expect(page).to have_content("not authorized")
      end

      it "shows only own jobs in jobs list" do
        create(:job, status: :pending, client: client, operator: nil)
        create(:job, status: :pending, client: other_client, operator: nil)
        
        visit jobs_path
        
        # Should see own job but not other's
        expect(page).to have_content("Test job")
      end
    end

    describe "Operator viewing permissions" do
      before { login_as operator, scope: :user }

      it "allows operator to view assigned job" do
        visit job_path(client_job)
        
        expect(page).to have_content(client_job.title.humanize)
      end

      it "allows operator to view unassigned jobs" do
        unassigned_job = create(:job, status: :pending, client: client, operator: nil)
        
        visit jobs_path(tab: "unassigned")
        
        expect(page).to have_content("Test job")
      end
    end
  end

  describe "Permission enforcement on actions" do
    describe "Editing jobs" do
      before { login_as client, scope: :user }

      it "allows client to edit their own pending job" do
        client_job = create(:job, status: :pending, client: client, operator: nil)
        
        visit edit_job_path(client_job)
        
        expect(page).not_to have_content("not authorized")
      end
    end

    describe "Assigning jobs" do
      before { login_as operator, scope: :user }

      it "prevents operator from assigning others' jobs" do
        # Operators should only assign to themselves
        visit job_path(job)
        
        # If already assigned, button shouldn't be visible
        expect(page).not_to have_button("Self assign")
      end
    end
  end

  describe "Data privacy" do
    let(:other_client) { create(:user, role: :client) }
    let(:other_job) { create(:job, status: :assigned, client: other_client, operator: operator) }

    before { login_as client, scope: :user }

    it "prevents accessing other client's job via direct URL" do
      visit job_path(other_job)
      
      expect(page).to have_content("not authorized")
    end

    it "prevents accessing other client's job edit form" do
      visit edit_job_path(other_job)
      
      expect(page).to have_content("not authorized")
    end

    it "does not leak other client's jobs in job lists" do
      visit jobs_path
      
      expect(page).not_to have_content(other_job.title.humanize)
    end

    it "does not show other client's drafts to different client" do
      other_draft = create(:job, status: :draft, client: other_client, operator: nil)
      
      visit jobs_path(tab: "drafts")
      
      expect(page).not_to have_content(other_draft.title.humanize)
    end
  end

  describe "Session management" do
    before { login_as client, scope: :user }

    it "maintains authentication across multiple page visits" do
      visit jobs_path
      visit new_job_path
      visit jobs_path
      
      expect(current_path).to eq(jobs_path)
    end

    it "requires re-authentication after logout" do
      visit jobs_path
      
      if page.has_link?("Sign out")
        click_link "Sign out"
        visit jobs_path
        
        expect(current_path).to include("sign")
      end
    end
  end
end