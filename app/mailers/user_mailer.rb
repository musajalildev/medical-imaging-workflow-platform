class UserMailer < ApplicationMailer
  layout 'mailer'

  # client emails

  # send client an email when their job status changes
  def send_job_status_change_email(job, initiator)
    @user = job.client
    return if @user.nil?

    @job = job
    @initiator = initiator
    mail(to: @user.email, subject: "Your job status has changed to #{@job.get_status_for_display}")
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

  # send client an email when a job is accepted by an operator
  def send_job_accepted_email(job)
    @user = job.client
    return if @user.nil?

    @job = job
    mail(to: @user.email, subject: "An operator has accepted your job")
  end

  # send client an email when their job has been dropped
  def send_job_dropped_email(job, initiator)
    return if job.nil? || initiator.nil?

    @initiator = initiator
    @job = job
    mail(to: job.client.email, subject: "Your job has been dropped")
  end

  # send client an email when their operator changes
  def send_operator_reassigned_email(job, old_operator, initiator)
    return if job.nil? || old_operator.nil? || initiator.nil?

    @initiator = initiator
    @old_operator = old_operator
    @job = job
    mail(to: job.client.email, subject: "Your job's operator has been reassigned")
  end

  # operator emails

  # send operator an email when a new job is created
  def send_new_job_email(job)
    @users = User.where(role: :operator)
    return if @users.empty?

    @job = job
    mail(to: @users.pluck(:email), subject: "A new job has become available")
  end

  def send_unassigned_from_job_email(job, operator, initiator)
    return if job.nil? || operator.nil? || initiator.nil?

    @initiator = initiator
    @job = job
    mail(to: operator.email, subject: "You have been unassigned from a job")
  end

  def send_assigned_to_job_email(job, initiator)
    return if job.nil? || initiator.nil?
    
    @initiator = initiator
    @job = job
    mail(to: job.operator.email, subject: "You have been assigned to a job")
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
end
