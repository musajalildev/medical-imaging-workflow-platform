require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  describe "#send_job_status_change_email" do
    it "sends to the client with the status in the subject" do
      client = create(:user, role: :client)
      job = create(:job, client: client, title: "Test Job", description: "Desc", status: :assigned)

      mail = described_class.send_job_status_change_email(job)

      expect(mail.to).to eq([client.email])
      expect(mail.subject).to eq("Your job status has changed to assigned")
    end
  end

  describe "#send_job_cancelled_email" do
    it "sends to the client with the job title in the subject" do
      client = create(:user, role: :client)
      job = create(:job, client: client, title: "Test Job", description: "Desc", status: :cancelled)

      mail = described_class.send_job_cancelled_email(job)

      expect(mail.to).to eq([client.email])
      expect(mail.subject).to eq("Your job Test Job has been cancelled")
    end
  end

  describe "#send_job_completed_email" do
    it "sends to the client with the job title in the subject" do
      client = create(:user, role: :client)
      job = create(:job, client: client, title: "Test Job", description: "Desc", status: :complete)

      mail = described_class.send_job_completed_email(job)

      expect(mail.to).to eq([client.email])
      expect(mail.subject).to eq("Your job Test Job has been completed")
    end
  end

  describe "#send_job_accepted_email" do
    it "sends to the client when an operator accepts a job" do
      client = create(:user, role: :client)
      job = create(:job, client: client, title: "Test Job", description: "Desc", status: :assigned)

      mail = described_class.send_job_accepted_email(job)

      expect(mail.to).to eq([client.email])
      expect(mail.subject).to eq("An operator has accepted your job")
    end
  end

  describe "#send_new_job_email" do
    it "sends to operators when a new job is created" do
      operator1 = create(:user, role: :operator, email: "op1@example.com")
      operator2 = create(:user, role: :operator, email: "op2@example.com")
      job = create(:job, title: "New Job", description: "Desc", status: :pending)

      mail = described_class.send_new_job_email(job)

      expect(mail.to).to include(operator1.email, operator2.email)
      expect(mail.subject).to eq("A new job has become available")
    end
  end

  describe "#send_sign_up_email" do
    it "sends to admins and owners with the request details" do
      admin = create(:user, role: :admin, email: "admin@example.com")
      owner = create(:user, role: :owner, email: "owner@example.com")

      mail = described_class.with(
        role: "client",
        comment: "Please approve",
        email: "newuser@example.com"
      ).send_sign_up_email

      expect(mail.to).to include(admin.email, owner.email)
      expect(mail.subject).to eq("New sign-up role request")
    end
  end
end