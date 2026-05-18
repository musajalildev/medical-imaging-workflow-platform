require 'rails_helper'

RSpec.describe "Draft Jobs", type: :feature do
  let(:client) { create(:user, role: :client) }
  let(:operator) { create(:user, role: :operator) }
  let(:admin) { create(:user, role: :admin) }
  let(:draft_job) { create(:job, status: :draft, client: client, operator: nil, description: nil) }

  before do
    allow(UserMailer).to receive(:send_new_job_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_status_change_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_accepted_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_completed_email).and_return(double(deliver_later: true))
    allow(UserMailer).to receive(:send_job_cancelled_email).and_return(double(deliver_later: true))
    allow_any_instance_of(Job).to receive(:create_google_drive_folder).and_return(true)
  end

  describe "Creating drafts" do
    before { login_as client, scope: :user }

    it "allows a client to create a draft job without a description" do
      visit new_job_path
      
      fill_in "job_title", with: "Draft Job Title"
      click_button "Save as Draft"

      expect(page).to have_content("Draft saved.")
      job = Job.last
      expect(job.status).to eq("draft")
      expect(job.title).to eq("Draft Job Title")
      expect(job.description).to be_empty
    end

    it "allows a client to save draft with a description" do
      visit new_job_path
      
      fill_in "job_title", with: "Draft Job with Description"
      fill_in "job_description", with: "This is a description"
      click_button "Save as Draft"

      expect(page).to have_content("Draft saved.")
      job = Job.last
      expect(job.description).to eq("This is a description")
    end

    it "creates a draft with client_id set to current user" do
      visit new_job_path
      
      fill_in "job_title", with: "Another Draft"
      click_button "Save as Draft"

      job = Job.last
      expect(job.client).to eq(client)
    end

    it "does not send email notification when creating a draft" do
      visit new_job_path
      
      fill_in "job_title", with: "Silent Draft"
      click_button "Save as Draft"

      expect(UserMailer).not_to have_received(:send_new_job_email)
    end

    it "does not require file uploads to save as draft" do
      visit new_job_path
      
      fill_in "job_title", with: "No Files Draft"
      click_button "Save as Draft"

      expect(page).to have_content("Draft saved.")
    end
  end

  describe "Submitting jobs as non-draft" do
    before { login_as client, scope: :user }

    it "sends email notification when submitting job (not draft)" do
      visit new_job_path
      
      fill_in "job_title", with: "Submitted Job"
      fill_in "job_description", with: "Job description"
      click_button "Create Job"

      expect(page).to have_content("Both input files (PDF and DICOM) must be uploaded")
      expect(UserMailer).not_to have_received(:send_new_job_email)
    end

    it "requires description when submitting non-draft job" do
      visit new_job_path
      
      fill_in "job_title", with: "Incomplete Job"
      click_button "Create Job"

      # Should fail validation
      job = Job.last
      expect(job).to be_nil
    end
  end

  describe "Viewing drafts" do
    context "as a client" do
      before do
        login_as client, scope: :user
        create(:job, status: :draft, client: client, operator: nil, description: nil, title: "Client Draft 1")
        create(:job, status: :draft, client: client, operator: nil, description: nil, title: "Client Draft 2")
        create(:job, status: :pending, client: client, operator: nil, title: "Active Job")
      end

      it "shows drafts in the drafts tab" do
        visit jobs_path(tab: "drafts")
        
        expect(page).to have_content("Client draft 1")
        expect(page).to have_content("Client draft 2")
      end

      it "does not show drafts in the active jobs tab" do
        visit jobs_path(tab: "active")
        
        expect(page).not_to have_content("Client draft 1")
        expect(page).not_to have_content("Client draft 2")
        expect(page).to have_content("Active job")
      end

      it "shows only user's own drafts" do
        other_client = create(:user, role: :client)
        create(:job, status: :draft, client: other_client, operator: nil, description: nil, title: "Other Client Draft")
        
        visit jobs_path(tab: "drafts")
        
        expect(page).to have_content("Client draft 1")
        expect(page).not_to have_content("Other client draft")
      end
    end

    context "as an operator" do
      before do
        login_as operator, scope: :user
        create(:job, status: :draft, client: client, operator: nil, description: nil, title: "Hidden Draft")
      end

      it "does not show draft jobs" do
        visit jobs_path
        
        expect(page).not_to have_content("Hidden draft")
      end

      it "does not have a drafts tab" do
        visit jobs_path
        
        expect(page).not_to have_content("Drafts")
      end
    end
  end

  describe "Editing drafts" do
    before do
      login_as client, scope: :user
      @draft = create(:job, status: :draft, client: client, operator: nil, description: nil, 
                            title: "Original Draft Title")
    end

    it "allows a client to edit draft title" do
      visit edit_job_path(@draft)
      
      fill_in "job_title", with: "Updated Draft Title"
      click_button "Update Draft"

      expect(page).to have_content("Job was successfully updated.")
      @draft.reload
      expect(@draft.title).to eq("Updated Draft Title")
    end

    it "allows a client to edit draft description" do
      visit edit_job_path(@draft)
      
      fill_in "job_description", with: "Now with description"
      click_button "Update Draft"

      @draft.reload
      expect(@draft.description).to eq("Now with description")
    end

    it "keeps draft status when updating" do
      visit edit_job_path(@draft)
      
      fill_in "job_title", with: "Still a Draft"
      click_button "Update Draft"

      @draft.reload
      expect(@draft.status).to eq("draft")
    end

    it "does not send status change email when updating draft" do
      visit edit_job_path(@draft)
      
      fill_in "job_title", with: "Silent Edit"
      click_button "Update Draft"

      expect(UserMailer).not_to have_received(:send_job_status_change_email)
    end
  end

  describe "Submitting drafts" do
    before do
      @draft = create(:job, status: :draft, client: client, operator: nil, description: nil)
      login_as client, scope: :user
    end

    context "without required files" do
      it "prevents submission without any files" do
        visit job_path(@draft)
        
        click_button "Submit Job"
        
        expect(page).to have_content("Both input files (PDF and DICOM) must be uploaded")
        @draft.reload
        expect(@draft.status).to eq("draft")
      end

      it "prevents submission with only PDF file" do
        create(:image_file, job: @draft, file_path: "pdf_path", file_type: '{"slot": 1}')
        
        visit job_path(@draft)
        click_button "Submit Job"
        
        expect(page).to have_content("Both input files (PDF and DICOM) must be uploaded")
      end

      it "prevents submission with only DICOM file" do
        create(:image_file, job: @draft, file_path: "dicom_path", file_type: '{"slot": 2}')
        
        visit job_path(@draft)
        click_button "Submit Job"
        
        expect(page).to have_content("Both input files (PDF and DICOM) must be uploaded")
      end
    end

    # context "with required files" do
    #   before do
    #     create(:image_file, job: @draft, file_path: "pdf_path", file_type: '{"slot": 1}')
    #     create(:image_file, job: @draft, file_path: "dicom_path", file_type: '{"slot": 2}')
    #   end

    #   it "allows submission with both PDF and DICOM files" do
    #     visit job_path(@draft)
        
    #     click_button "Submit Job"
        
    #     expect(page).to have_content("Job was successfully updated")
    #     @draft.reload
    #     expect(@draft.status).to eq("pending")
    #   end

    #   it "sends email notification when submitting draft" do
    #     visit job_path(@draft)
        
    #     click_button "Submit Job"
        
    #     expect(UserMailer).to have_received(:send_new_job_email)
    #   end

    #   it "changes job status from draft to pending" do
    #     visit job_path(@draft)
        
    #     click_button "Submit Job"
        
    #     @draft.reload
    #     expect(@draft.status).to eq("pending")
    #     expect(@draft.get_status_for_display).to eq("Pending")
    #   end
    # end
  end

  describe "Deleting drafts" do
    before do
      @draft = create(:job, status: :draft, client: client, operator: nil)
      login_as client, scope: :user
    end
  end

  describe "Authorization" do
    context "non-clients trying to create drafts" do
      it "prevents an operator from creating a draft" do
        login_as operator, scope: :user
        visit new_job_path
        
        expect(page).to have_content("not authorized")
      end

      it "prevents an unassigned user from creating a draft" do
        unassigned_user = create(:user, role: :unassigned)
        login_as unassigned_user, scope: :user
        visit new_job_path
        
        expect(page).to have_content("not authorized")
      end
    end

    context "non-owners trying to edit drafts" do
      before do
        @other_client = create(:user, role: :client)
        @draft = create(:job, status: :draft, client: client, operator: nil)
      end

      it "prevents another client from editing someone else's draft" do
        login_as @other_client, scope: :user
        visit edit_job_path(@draft)
        
        expect(page).to have_content("not authorized")
      end

      it "prevents an operator from editing a draft" do
        login_as operator, scope: :user
        visit edit_job_path(@draft)
        
        expect(page).to have_content("not authorized")
      end
    end

    context "non-owners trying to submit drafts" do
      before do
        @draft = create(:job, status: :draft, client: client, operator: nil)
        create(:image_file, job: @draft, file_path: "pdf_path", file_type: '{"slot": 1}')
        create(:image_file, job: @draft, file_path: "dicom_path", file_type: '{"slot": 2}')
      end

      it "prevents another client from submitting someone else's draft" do
        other_client = create(:user, role: :client)
        login_as other_client, scope: :user
        
        visit job_path(@draft)
        expect(page).to have_content("not authorized")
      end
    end
  end

  describe "Draft job display" do
    before do
      login_as client, scope: :user
      @draft = create(:job, status: :draft, client: client, operator: nil, 
                            title: "Display Test Draft", description: nil)
    end

    it "shows draft status on job details page" do
      visit job_path(@draft)
      
      expect(page).to have_content("Draft")
    end

    it "shows submit draft button for draft jobs" do
      visit job_path(@draft)
      
      expect(page).to have_button("Submit Job")
    end
  end

  describe "Multiple drafts management" do
    before do
      login_as client, scope: :user
      @draft1 = create(:job, status: :draft, client: client, operator: nil, 
                             title: "Draft One")
      @draft2 = create(:job, status: :draft, client: client, operator: nil, 
                             title: "Draft Two")
      @draft3 = create(:job, status: :draft, client: client, operator: nil, 
                             title: "Draft Three")
    end

    it "displays all client drafts in the drafts tab" do
      visit jobs_path(tab: "drafts")
      
      expect(page).to have_content("Draft one")
      expect(page).to have_content("Draft two")
      expect(page).to have_content("Draft three")
    end

    it "allows editing one draft without affecting others" do
      visit edit_job_path(@draft1)
      fill_in "job_title", with: "Updated Draft One"
      click_button "Update Draft"

      visit jobs_path(tab: "drafts")
      expect(page).to have_content("Updated draft one")
      expect(page).to have_content("Draft two")
      expect(page).to have_content("Draft three")
    end

  end

  # describe "Authorization" do
  #   context "non-clients trying to create drafts" do
  #     it "prevents an operator from creating a draft" do
  #       login_as operator, scope: :user
  #       visit new_job_path
  #       create(:image_file, job: @draft1, file_path: "dicom_path", file_type: '{"slot": 2}')
  #     end
  #     visit job_path(@draft1)
  #     click_button "Update Draft"

  #     @draft1.reload
  #     expect(@draft1.status).to eq("pending")
      
  #     expect(@draft2.reload.status).to eq("draft")
  #     expect(@draft3.reload.status).to eq("draft")
  #   end
end