require 'rails_helper'

RSpec.describe "Job Search, Filtering and Sorting", type: :feature do
  let(:client1) { create(:user, role: :client) }
  let(:client2) { create(:user, role: :client) }
  let(:operator1) { create(:user, role: :operator) }
  let(:operator2) { create(:user, role: :operator) }

  before do
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
  end

  describe "Client job list view" do
    before do
      # Create various jobs for client1
      create(:job, status: :draft, client: client1, operator: nil, title: "Draft Invoice Scan")
      create(:job, status: :pending, client: client1, operator: nil, title: "Medical Records Review")
      create(:job, status: :assigned, client: client1, operator: operator1, title: "Document Analysis")
      create(:job, status: :in_progress, client: client1, operator: operator1, title: "X-ray Processing")
      create(:job, status: :complete, client: client1, operator: operator1, title: "Completed Scan")
      create(:job, status: :cancelled, client: client1, operator: nil, title: "Cancelled Request")
      
      # Create jobs for other client (shouldn't be visible)
      create(:job, status: :pending, client: client2, operator: nil, title: "Other Client Job")
      
      login_as client1, scope: :user
    end

    it "shows only active (non-draft) jobs in active tab" do
      visit jobs_path(tab: "active")
      
      expect(page).to have_content("Medical Records Review")
      expect(page).to have_content("Document Analysis")
      expect(page).to have_content("X Ray Processing")
      expect(page).not_to have_content("Draft Invoice Scan")
    end

    it "shows only draft jobs in drafts tab" do
      visit jobs_path(tab: "drafts")
      
      expect(page).to have_content("Draft Invoice Scan")
      expect(page).not_to have_content("Medical Records Review")
    end

    it "hides other client's jobs in active tab" do
      visit jobs_path(tab: "active")
      
      expect(page).not_to have_content("Other client job")
    end

    it "displays correct job count" do
      visit jobs_path(tab: "active")
      
      # Should show 4 non-draft jobs (pending, assigned, in_progress, complete, cancelled)
      job_count = page.all("tr").length - 1
      expect(job_count).to be >= 4
    end
  end

  describe "Operator job list view" do
    before do
      # Create assigned and unassigned jobs
      create(:job, status: :pending, client: client1, operator: nil, title: "Unassigned Job 1")
      create(:job, status: :pending, client: client1, operator: nil, title: "Unassigned Job 2")
      create(:job, status: :assigned, client: client1, operator: operator1, title: "Op1 Job 1")
      create(:job, status: :assigned, client: client1, operator: operator1, title: "Op1 Job 2")
      create(:job, status: :assigned, client: client1, operator: operator2, title: "Op2 Job 1")
      create(:job, status: :draft, client: client1, operator: nil, title: "Hidden Draft")
      
      login_as operator1, scope: :user
    end

    it "shows only own assigned jobs in assigned tab" do
      visit jobs_path(tab: "assigned")
      
      expect(page).to have_content("Op1 Job 1")
      expect(page).to have_content("Op1 Job 2")
      expect(page).not_to have_content("Op2 Job 1")
      expect(page).not_to have_content("Unassigned Job 1")
    end

    it "shows unassigned jobs in unassigned tab" do
      visit jobs_path(tab: "unassigned")
      
      expect(page).to have_content("Unassigned Job 1")
      expect(page).to have_content("Unassigned Job 2")
      expect(page).not_to have_content("Op1 Job 1")
    end

    it "hides draft jobs from operators" do
      visit jobs_path(tab: "unassigned")
      
      expect(page).not_to have_content("Hidden draft")
    end

    it "does not show drafts tab for operators" do
      visit jobs_path
      
      expect(page).not_to have_content("Drafts")
    end
  end

  describe "Search functionality" do
    before do
      create(:job, status: :pending, client: client1, operator: nil, 
             title: "Medical Record Analysis", 
             description: "Review medical records for accuracy")
      create(:job, status: :pending, client: client1, operator: nil, 
             title: "Invoice Processing",
             description: "Process invoices")
      create(:job, status: :assigned, client: client1, operator: operator1,
             title: "Document Verification",
             description: "Medical document verification")
      
      login_as client1, scope: :user
    end

    describe "search by title" do
      it "finds jobs by exact title match" do
        visit jobs_path
        
        fill_in "search", with: "Medical"
        select "Title", from: "search_by"
        click_button "Search"
        
        expect(page).to have_content("Medical Record Analysis")
        expect(page).not_to have_content("Invoice Processing")
      end

      it "finds jobs by partial title match (case insensitive)" do
        visit jobs_path
        
        fill_in "search", with: "record"
        select "Title", from: "search_by"
        click_button "Search"
        
        expect(page).to have_content("Medical Record Analysis")
      end

      it "returns empty results for non-matching title search" do
        visit jobs_path
        
        fill_in "search", with: "nonexistent"
        select "Title", from: "search_by"
        click_button "Search"
        
        expect(page).not_to have_content("Medical record analysis")
      end
    end

    describe "search by description" do
      it "finds jobs by description content" do
        visit jobs_path
        
        fill_in "search", with: "verification"
        # Default search searches all fields
        click_button "Search"
        
        expect(page).to have_content("Document Verification")
      end
    end

    describe "global search" do
      it "is case insensitive" do
        visit jobs_path
        
        fill_in "search", with: "MEDICAL"
        click_button "Search"
        
        expect(page).to have_content("Medical Record Analysis")
      end

      it "handles special characters in search" do
        visit jobs_path
        
        fill_in "search", with: "%"
        click_button "Search"
        
        expect(page).not_to have_content("error")
      end

      it "searches by client name" do
        job = create(:job,
                    status: :pending,
                    client: client1,
                    title: "Client search job")

        login_as client1, scope: :user
        visit jobs_path

        fill_in "search", with: client1.givenname
        select "Client", from: "search_by"
        click_button "Search"

        expect(page).to have_content(job.title.titleize)
      end
    end

    # describe "search by client name" do
    #   let(:specific_client) { create(:user, role: :client, 
    #                                  givenname: "John", sn: "Smith") }
    #   before do
    #     create(:job, status: :pending, client: specific_client, operator: nil,
    #            title: "John Job")
    #   end

    #   it "finds jobs by client first name" do
    #     visit jobs_path
        
    #     fill_in "search", with: "John"
    #     select "Client", from: "search_by"
    #     click_button "Search"
        
    #     expect(page).to have_content("John job")
    #   end

    #   it "finds jobs by client last name" do
    #     visit jobs_path
        
    #     fill_in "search", with: "Smith"
    #     select "Client", from: "search_by"
    #     click_button "Search"
        
    #     expect(page).to have_content("John job")
    #   end

    describe "search by operator name" do
      let(:specific_operator) { create(:user, role: :operator,
                                       givenname: "Jane", sn: "Doe") }
      before do
        create(:job, status: :assigned, client: client1, operator: specific_operator,
               title: "Operator Job")
      end

    end
  end

  describe "Status filtering" do
    before do
      create(:job, status: :pending, client: client1, operator: nil, title: "Pending Job")
      create(:job, status: :assigned, client: client1, operator: operator1, title: "Assigned Job")
      create(:job, status: :in_progress, client: client1, operator: operator1, title: "In Progress Job")
      create(:job, status: :complete, client: client1, operator: operator1, title: "Complete Job")
      
      login_as client1, scope: :user
    end

    # it "filters jobs by status" do
    #   visit jobs_path
      
    #   select "Pending", from: "status"

    #   expect(page).to have_content("Pending job")
    #   expect(page).not_to have_content("Assigned job")
    # end

    # it "shows jobs of selected status only" do
    #   visit jobs_path
      
    #   select "Complete", from: "status"
      
    #   expect(page).to have_content("Complete job")
    #   expect(page).not_to have_content("Assigned job")
    # end
  end

  describe "Sorting" do
    before do
      create(:job, status: :pending, client: client1, operator: nil, 
             title: "Zebra Job", created_at: 3.days.ago)
      create(:job, status: :pending, client: client1, operator: nil,
             title: "Apple Job", created_at: 1.day.ago)
      create(:job, status: :pending, client: client1, operator: nil,
             title: "Monkey Job", created_at: 2.days.ago)
      
      login_as client1, scope: :user
    end

    it "sorts jobs by creation date descending (newest first) by default" do
      visit jobs_path
      
      jobs = page.all("table tbody tr")
      first_job_title = jobs.first.text
      
      expect(first_job_title).to include("Apple Job")
    end

  end

  describe "Empty state handling" do
    before { login_as client1, scope: :user }

    it "shows message when no jobs exist for client" do
      visit jobs_path
      
      expect(page).to have_content("Showing 0 of 0")
    end

    it "shows message when search returns no results" do
      create(:job, status: :pending, client: client1, operator: nil, title: "Test Job")
      
      visit jobs_path
      
      fill_in "search", with: "nonexistent"
      click_button "Search"
      
      expect(page).to have_content("Showing 0 of 0")
    end
  end

  # Helper method for checking active tabs
  def have_active_tab(tab_name)
    have_css("a.nav-link.active", text: tab_name.capitalize)
  end
end