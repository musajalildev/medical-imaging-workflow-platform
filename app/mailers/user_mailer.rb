class UserMailer < ApplicationMailer
  default from: 'noreplay@example.com'
  layout 'mailer'

  # client emails

  # send client an email when their job status changes
  def send_job_status_change_email(job)
    @user = job.client
    @job = job
    mail(to: @user.email, subject: "Your job status has changed to #{@job.status}")
  end

  # send client an email when their job is cancelled
  def send_job_cancelled_email(job)
    @user = job.client
    @job = job
    mail(to: @user.email, subject: "Your job #{@job.title} has been cancelled")
  end

  # send client an email when their job is completed
  def send_job_completed_email(job)
    @user = job.client
    @job = job
    mail(to: @user.email, subject: "Your job #{@job.title} has been completed")
  end

  # operator emails

  # send operator an email when a job is assigned to them
  def send_job_assigned_email(job)
    @user = job.operator
    @job = job
    mail(to: @user.email, subject: "You have been assigned to job #{@job.title}")
  end

  # send operator an email when a new job is created
  def send_new_job_email(job)
    @user = job.operator
    @job = job
    mail(to: @user.email, subject: "A new job #{@job.title} has become available")
  end
end
