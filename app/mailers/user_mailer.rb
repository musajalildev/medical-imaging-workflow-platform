class UserMailer < ApplicationMailer
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

  # send client an email when a job is accepted by an operator
  def send_job_accepted_email(job)
    @user = job.client
    @job = job
    mail(to: @user.email, subject: "An operator has accepted your job")
  end

  # operator emails

  # send operator an email when a new job is created
  def send_new_job_email(job)
    @user = User.where(role: :operator)
    @job = job
    @user.each do |operator|
      mail(to: operator.email, subject: "A new job has become available")
    end
  end

  # admin emails

  # send admin an email when a user signs up
  def sign_up_email(email, role, comment)
    @user = User.where(role: :admin || :owner)
    @role = role
    @comment = comment
    @user.each do |admin|
      mail(to: admin.email, subject: "New user sign-up: #{@user.email}")
    end
  end
end
