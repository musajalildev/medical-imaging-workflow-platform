class UserMailer < ApplicationMailer
  layout 'mailer'

  # client emails

  # send client an email when a job is accepted by an operator
  def send_job_accepted_email(job)
    return if job.nil? || job.client.nil?

    @user = job.client
    @job = job
    mail(to: @user.email, subject: "An operator has accepted your job")
  end

  # send client an email when their job has been dropped
  def send_job_dropped_email(job, initiator)
    return if job.nil? || initiator.nil? || job.client.nil?

    @initiator = initiator
    @job = job
    mail(to: job.client.email, subject: "Your job has been dropped")
  end

  # send client an email when their operator changes
  def send_operator_reassigned_email(job, old_operator, initiator)
    return if job.nil? || old_operator.nil? || initiator.nil? || job.client.nil?

    @initiator = initiator
    @old_operator = old_operator
    @job = job
    mail(to: job.client.email, subject: "Your job's operator has been reassigned")
  end

  # send client an email when a report is uploaded to their job
  def send_report_uploaded_email(job, initiator)
    return if job.nil? || job.client.nil? || initiator.nil?

    @initiator = initiator
    @job = job
    mail(to: job.client.email, subject: "A report has been uploaded to your job")
  end

  # operator emails

  # send operator an email when a new job is created
  def send_new_job_email(job, operator)
    return if job.nil? || operator.nil?

    @job = job
    mail(to: operator.email, subject: "A new job has become available")
  end

  # send operator an email when an admin unassigns them from a job
  def send_unassigned_from_job_email(job, operator, initiator)
    return if job.nil? || operator.nil? || initiator.nil?

    @initiator = initiator
    @job = job
    mail(to: operator.email, subject: "You have been unassigned from a job")
  end

  # send operator an email when an admin assigns them to a job
  def send_assigned_to_job_email(job, initiator)
    return if job.nil? || initiator.nil? || job.operator.nil?
    
    @initiator = initiator
    @job = job
    mail(to: job.operator.email, subject: "You have been assigned to a job")
  end

  # client / operator emails

  # send user an email when their job status changes
  def send_job_status_change_email(job, initiator, user)
    return if user.nil? || job.nil? || initiator.nil?

    @user = user
    @job = job
    @initiator = initiator
    mail(to: user.email, subject: "Your job status has changed to #{@job.get_status_for_display}")
  end

  # send user an email when their job is cancelled
  def send_job_cancelled_email(job, user, initiator)
    return if user.nil? || job.nil?

    @initiator = initiator
    @job = job
    mail(to: user.email, subject: "Your job #{@job.title} has been cancelled")
  end

  # send user an email when their job is completed
  def send_job_completed_email(job, user)
    return if user.nil? || job.nil?

    @job = job
    mail(to: user.email, subject: "Your job #{@job.title} has been completed")
  end

  # admin emails

  # send admin an email when a user signs up
  def send_sign_up_email(admin, new_user_email, role, comment)
    return if admin.nil? || role.nil? || new_user_email.nil?

    @role = role
    @comment = comment
    @email = new_user_email

    mail(to: admin.email, subject: "New sign-up role request")
  end
end
