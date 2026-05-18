require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#send_job_status_change_email" do
    it "sends to the client with the status in the subject" do
      job = double(
        title: "Test Job",
        get_status_for_display: "Assigned"
      )
      initiator = double(email: "initiator@example.com")
      user = double(email: "client@example.com")

      mail = described_class.send_job_status_change_email(job, initiator, user).deliver_now

      expect(mail.to).to eq(["client@example.com"])
      expect(mail.subject).to eq("Your job status has changed to Assigned")
      expect(mail.body.encoded).to include("Test Job")
      expect(mail.body.encoded).to include("Assigned")
      expect(mail.body.encoded).to include("initiator@example.com")
    end
  end

  describe "#send_job_cancelled_email" do
    it "sends to the client with the job title in the subject" do
      job = double(title: "Test Job")
      user = double(email: "client@example.com")
      initiator = double(email: "initiator@example.com")

      mail = described_class.send_job_cancelled_email(job, user, initiator).deliver_now

      expect(mail.to).to eq(["client@example.com"])
      expect(mail.subject).to eq("Your job Test Job has been cancelled")
      expect(mail.body.encoded).to include("Test Job")
    end
  end

  describe "#send_job_completed_email" do
    it "sends to the client with the job title in the subject" do
      job = double(
        title: "Test Job",
        operator: double(email: "op@example.com")
      )
      user = double(email: "client@example.com")

      mail = described_class.send_job_completed_email(job, user).deliver_now

      expect(mail.to).to eq(["client@example.com"])
      expect(mail.subject).to eq("Your job Test Job has been completed")
      expect(mail.body.encoded).to include("Test Job")
      expect(mail.body.encoded).to include("op@example.com")
    end
  end

  describe "#send_new_job_email" do
    it "sends to the operator with the correct subject" do
      job = double(title: "New Job")
      operator = double(email: "op@example.com")

      mail = described_class.send_new_job_email(job, operator).deliver_now

      expect(mail.to).to eq(["op@example.com"])
      expect(mail.subject).to eq("A new job has become available")
      expect(mail.body.encoded).to include("New Job")
    end
  end

  describe "#send_sign_up_email" do
    it "sends to the admin with the request details" do
      admin = double(email: "admin@example.com")

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
end