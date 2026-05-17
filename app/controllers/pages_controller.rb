class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :landing]

  
  def home
  end

  def landing
    @total_jobs = Job.count
    completed_jobs = Job.where(status: :complete)
    @completed_jobs = completed_jobs.count
    @cancelled_jobs = Job.where(status: :cancelled).count
    @pending_jobs = Job.where(status: :pending).count
    @active_jobs = Job.where(status: [:assigned, :in_progress]).count

    if @completed_jobs.positive?
      # Calculate time diff in seconds and convert to days
      avg_seconds = completed_jobs.average("EXTRACT(EPOCH FROM (updated_at - created_at))")
      @avg_completion_time = (avg_seconds.to_f / 86400).round(1)
    else
      @avg_completion_time = 0
    end

    total_closed = @completed_jobs + @cancelled_jobs
    @completion_rate = total_closed.positive? ? ((@completed_jobs.to_f / total_closed) * 100).round(1) : 0
  end

  def sign_up
  end

  def send_sign_up_email
    # cache to prevent spamming admins with multiple emails if a user signs up multiple times in a short period
    cache_key = "#{@email}_sign_up_email"

    if Rails.cache.read(cache_key)
      redirect_to sign_up_path, alert: "You can only send one sign-up email per week. Please wait for an admin to review your previous request."
      return
      
    elsif !params[:role_selection].present?
      redirect_to sign_up_path, alert: "Please select a role."
      return

    else
      role = params[:role_selection]
      comment = params[:comment]

      # only cache if email is sent successfully to prevent blocking users if there is an issue with email delivery
      Rails.cache.write(cache_key, true, expires_in: 7.day)
      User.where(role: :admin).each do |admin|
        UserMailer.with(admin, current_user.email, role, comment).send_sign_up_email.deliver_later
      end
      redirect_to sign_up_path, notice: "Sign up email sent successfully!"
    end
  end

end
