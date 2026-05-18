require 'rails_helper'

RSpec.describe "Job Assignment and Self-Assignment", type: :feature do
  let(:operator1) { create(:user, role: :operator) }
  let(:operator2) { create(:user, role: :operator) }
  let(:client) { create(:user, role: :client) }
  let(:unassigned_job) { create(:job, status: :pending, client: client, operator: nil, 
                                      title: "Unassigned Job") }
  let(:assigned_job) { create(:job, status: :assigned, client: client, operator: operator1,
                                      title: "Assigned Job") }

  before do
    allow(UserMailer).to receive(:send_job_accepted_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
  end

  describe "Operator job assignment flow" do
    before { login_as operator1, scope: :user }

    it "shows unassigned jobs in the unassigned tab" do
      visit jobs_path(tab: "unassigned")
      
      expect(page).to have_content("Unassigned jobs")
    end

    it "does not allow assigning already assigned jobs" do
      visit job_path(assigned_job)
      
      expect(page).not_to have_button("Self assign")
    end

  end

  describe "Job assignment visibility" do
    context "as operator viewing their own jobs" do
      before { login_as operator1, scope: :user }

      it "shows assigned jobs in the assigned tab" do
        visit jobs_path(tab: "assigned")
        
        expect(page).to have_content("Jobs")
      end

      it "does not show other operators' jobs in assigned tab" do
        other_operator_job = create(:job, status: :assigned, client: client, 
                                          operator: operator2, title: "Other Op Job")
        
        visit jobs_path(tab: "assigned")
        
        expect(page).to have_content("Jobs")
        expect(page).not_to have_content("Other op job")
      end

      it "shows job details for assigned jobs" do
        visit job_path(assigned_job)
        
        expect(page).to have_content("Assigned Job")
        expect(page).to have_content("Assigned")
      end
    end

    context "as client viewing jobs" do
      before { login_as client, scope: :user }

      it "shows who the job is assigned to" do
        visit job_path(assigned_job)
        
        expect(page).to have_content(operator1.email)
      end

      it "shows unassigned status for unassigned jobs" do
        visit job_path(unassigned_job)
        
        expect(page).not_to have_content(operator1.email)
      end

      it "does not show assignment/operator interface elements" do
        visit job_path(unassigned_job)
        
        expect(page).not_to have_button("Self assign")
      end
    end
  end

  describe "Operator workflow after assignment" do
    before { login_as operator1, scope: :user }

    it "allows status updates after assignment" do
      visit job_path(assigned_job)
      
      expect(page).to have_select("job_status")
    end

    it "allows file uploads after assignment" do
      visit job_path(assigned_job)
      
      expect(page).to have_button("Upload report file")
    end

    it "allows marking job as complete after assignment" do
      visit job_path(assigned_job)
      
      expect(page).to have_button("Mark as Complete")
    end

    it "allows cancelling job after assignment" do
      visit job_path(assigned_job)
      
      expect(page).to have_button("Cancel Job")
    end
  end

  describe "Assignment edge cases" do
    before { login_as operator1, scope: :user }

    it "allows a different operator to view assigned jobs" do
      assigned_job  # Create the assigned job
      
      login_as operator2, scope: :user
      visit jobs_path(tab: "assigned")
      
      expect(page).not_to have_content("Assigned job")
    end
  end
end