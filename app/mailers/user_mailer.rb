class UserMailer < ApplicationMailer
  layout 'mailer'

  # client emails

  # send client an email when their job status changes
  def send_job_status_change_email(job)
    @user = job.client
    return if @user.nil?

    @job = job
    mail(to: @user.email, subject: "Your job status has changed to #{@job.status}")
  end

  # send client an email when their job is cancelled
  def send_job_cancelled_email(job)
    @user = job.client
    return if @user.nil?

    @job = job
    mail(to: @user.email, subject: "Your job #{@job.title} has been cancelled")
  end

  # send client an email when their job is completed
  def send_job_completed_email(job)
    @user = job.client
    return if @user.nil?

    @job = job
    mail(to: @user.email, subject: "Your job #{@job.title} has been completed")
  end

  # operator emails

  # send client an email when a job is accepted by an operator
  def send_job_accepted_email(job)
    @user = job.client
    return if @user.nil?

    @job = job
    mail(to: @user.email, subject: "An operator has accepted your job")
  end

  # operator emails

  # send operator an email when a new job is created
  def send_new_job_email(job)
    @users = User.where(role: :operator)
    return if @users.empty?

    @job = job
    mail(to: @users.pluck(:email), subject: "A new job has become available")
  end

  # admin emails

  # send admin an email when a user signs up
  def send_sign_up_email
    @users = User.where(role: [:admin, :owner])
    return if @users.empty?

    @role = params[:role]
    @comment = params[:comment]
    @email = params[:email]

    mail(
      to: @users.pluck(:email),
      subject: "New sign-up role request"
    )
  end

  def send_help_email(recipient, initiator, job, issue, expansion)
    # recipient, initiator, issue and expansion are required
    return if recipient.blank? || initiator.blank? || issue.blank?

    @job = job
    @initiator = initiator
    @issue = issue
    @expansion = expansion

    mail(to: recipient.email, subject: "New help request from user: #{initiator.email}")
  end
end