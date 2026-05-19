require "rails_helper"

RSpec.describe UserMailer, type: :mailer do

  let(:client) { double(email: "client@example.com") }
  let(:operator) { double(email: "operator@example.com") }
  let(:admin) { double(email: "admin@example.com") }

  # client emails

  describe "#send_job_accepted_email" do
    it "sends an email to the jobs client with the correct user listed as new operator" do
      job = double(title: "New Job", client: client, operator: operator)

      mail = described_class.send_job_accepted_email(job).deliver_now

      expect(mail.to).to eq(["client@example.com"])
      expect(mail.subject).to eq("An operator has accepted your job")
      expect(mail.body.encoded).to include("New Job")
      expect(mail.body.encoded).to include(operator.email)
    end
  end

  describe "send_job_dropped_email" do
    context "when an operator drops the job" do
      it "send the client an email telling them their operator dropped the job" do
        job = double(title: "New Job", client: client)

        mail = described_class.send_job_dropped_email(job, operator).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("Your job has been dropped")
        expect(mail.body.encoded).to include("New Job")
        expect(mail.body.encoded).to include(operator.email)
      end
    end
    context "when an admin drops the job" do
      it "send the client an email telling them an admin dropped the job" do
        job = double(title: "New Job", client: client)

        mail = described_class.send_job_dropped_email(job, admin).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("Your job has been dropped")
        expect(mail.body.encoded).to include("New Job")
        expect(mail.body.encoded).to include(admin.email)
      end
    end
  end

  describe "send_operator_reassigned_email" do
    it "send the client an email telling them their operator was changed from op A to op B by the admin" do
      new_operator = double(email: "new_operator@example.com")
      old_operator = operator
      job = double(title: "New Job", client: client, operator: new_operator)

      mail = described_class.send_operator_reassigned_email(job, old_operator, admin).deliver_now

      expect(mail.to).to eq(["client@example.com"])
      expect(mail.subject).to eq("Your job's operator has been reassigned")
      expect(mail.body.encoded).to include("New Job")
      expect(mail.body.encoded).to include(admin.email)
      expect(mail.body.encoded).to include(new_operator.email)
      expect(mail.body.encoded).to include(old_operator.email)
    end
  end

  describe "send_report_uploaded_email" do
    context "when an operator uploads the report" do
      it "send the client an email telling them the report was uploaded by their operator" do
        job = double(title: "New Job", client: client, operator: operator)

        mail = described_class.send_report_uploaded_email(job, operator).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("A report has been uploaded to your job")
        expect(mail.body.encoded).to include("New Job")
        expect(mail.body.encoded).to include(operator.email)
      end
    end
    context "when an admin uploads the report" do
      it "send the client an email telling them an admin uploaded the report to their job" do
        job = double(title: "New Job", client: client, operator: operator)

        mail = described_class.send_report_uploaded_email(job, admin).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("A report has been uploaded to your job")
        expect(mail.body.encoded).to include("New Job")
        expect(mail.body.encoded).to include(admin.email)
      end
    end
  end 

  # operator emails

  describe "#send_new_job_email" do
    it "sends to the operator with the correct subject" do
      job = double(title: "New Job", client: client)

      mail = described_class.send_new_job_email(job, operator).deliver_now

      expect(mail.to).to eq(["operator@example.com"])
      expect(mail.subject).to eq("A new job has become available")
      expect(mail.body.encoded).to include("New Job")
    end
  end

  describe "send_unassigned_from_job_email" do
    it "tells the operator they were unassigned from a job by an admin" do
      job = double(title: "New Job", client: client)

      mail = described_class.send_unassigned_from_job_email(job, operator, admin).deliver_now

      expect(mail.to).to eq(["operator@example.com"])
      expect(mail.subject).to eq("You have been unassigned from a job")
      expect(mail.body.encoded).to include("New Job")
      expect(mail.body.encoded).to include(admin.email)
    end
  end

  describe "send_assigned_to_job_email" do
    it "tells the operator they were assigned to a job by an admin" do
      job = double(title: "New Job", client: client, operator: operator)

      mail = described_class.send_assigned_to_job_email(job, admin).deliver_now

      expect(mail.to).to eq(["operator@example.com"])
      expect(mail.subject).to eq("You have been assigned to a job")
      expect(mail.body.encoded).to include("New Job")
      expect(mail.body.encoded).to include(admin.email)
    end
  end

  # client / operator emails

  describe "#send_job_status_change_email" do
    context "when an operator updates the status on a job" do
      it "sends an email to the client with the status in the subject" do
        job = double(
          title: "Test Job",
          get_status_for_display: "Assigned"
        )

        mail = described_class.send_job_status_change_email(job, operator, client).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("Your job status has changed to Assigned")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include("Assigned")
        expect(mail.body.encoded).to include(operator.email)
      end
    end
    context "when an admin updates the status on a job" do
      it "sends an email to the operator with the status in the subject" do
        job = double(
          title: "Test Job",
          get_status_for_display: "Assigned"
        )

        mail = described_class.send_job_status_change_email(job, admin, operator).deliver_now

        expect(mail.to).to eq(["operator@example.com"])
        expect(mail.subject).to eq("Your job status has changed to Assigned")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include("Assigned")
        expect(mail.body.encoded).to include(admin.email)
      end
    end
  end

  describe "#send_job_cancelled_email" do
    context "when the operator cancels the job" do
      it "sends to the client with the job title in the subject" do
        job = double(title: "Test Job")

        mail = described_class.send_job_cancelled_email(job, client, operator).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("Your job Test Job has been cancelled")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include(operator.email)
      end
    end
    context "when an admin cancels the job" do
      it "sends to the operator with the job title in the subject" do
        job = double(title: "Test Job")

        mail = described_class.send_job_cancelled_email(job, operator, admin).deliver_now

        expect(mail.to).to eq(["operator@example.com"])
        expect(mail.subject).to eq("Your job Test Job has been cancelled")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include(admin.email)
      end
    end
  end

  describe "#send_job_completed_email" do
    context "when the operator completes the job" do
      it "sends to the client with the job title in the subject" do
        job = double(title: "Test Job")

        mail = described_class.send_job_completed_email(job, client, operator).deliver_now

        expect(mail.to).to eq(["client@example.com"])
        expect(mail.subject).to eq("Your job Test Job has been completed")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include(operator.email)
      end
    end
    context "when an admin completes the job" do
      it "sends to the operator with the job title in the subject" do
        job = double(title: "Test Job")

        mail = described_class.send_job_completed_email(job, operator, admin).deliver_now

        expect(mail.to).to eq(["operator@example.com"])
        expect(mail.subject).to eq("Your job Test Job has been completed")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include(admin.email)
      end
    end
  end

  # admin emails

  describe "#send_sign_up_email" do
    it "sends to the admin with the request details" do

      mail = described_class.send_sign_up_email(
        admin,
        "new.user@example.com",
        "client",
        "Please approve"
      ).deliver_now

      expect(mail.to).to eq(["admin@example.com"])
      expect(mail.subject).to eq("New sign-up role request")
      expect(mail.body.encoded).to include("new.user@example.com")
      expect(mail.body.encoded).to include("client")
      expect(mail.body.encoded).to include("Please approve")
    end
  end

  describe "send_help_email" do
    context "when its an issue with a job attached" do
      it "sends an email to the admin with the users help request and the job" do
        job = double(id: 1, title: "Test Job", client: client)

        mail = described_class.send_help_email(
          admin,
          client,
          job,
          "some issue",
          "some expansion"
        ).deliver_now

        expect(mail.to).to eq(["admin@example.com"])
        expect(mail.subject).to eq("New help request from user: client@example.com")
        expect(mail.body.encoded).to include("Test Job")
        expect(mail.body.encoded).to include("some issue")
        expect(mail.body.encoded).to include("some expansion")
      end
    end
    context "when its an issue with no job attached" do
      it "sends an email to the admin with the users help request" do
        mail = described_class.send_help_email(
          admin,
          client,
          nil,
          "some issue",
          "some expansion"
        ).deliver_now

        expect(mail.to).to eq(["admin@example.com"])
        expect(mail.subject).to eq("New help request from user: client@example.com")
        expect(mail.body.encoded).to include("not involving a job.")
        expect(mail.body.encoded).to include("some issue")
        expect(mail.body.encoded).to include("some expansion")
      end
    end
  end
end