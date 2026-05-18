class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :landing]
  before_action :authorize_pages, only: [ :sign_up, :send_sign_up_email, :help, :send_help_email]

  
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

  def help
  end

  def send_help_email
    # verify all necessary parameters are here
    # job is not required, only issue and expansion
    if params[:issue_type].blank?
      return redirect_to help_path, alert: "Please select an issue."
    elsif params[:issue_type] == "Other" && params[:expansion].blank? 
      return redirect_to help_path, alert: "Please provide an explanation of your issue."
    else
      # paramters provided are ok
      job = Job.find_by(id: params[:job_id]) if params[:job_id].present?
      issue = params[:issue_type]
      expansion = params[:expansion]

      admins = User.where(role: :admin)
      if admins.empty?
        return redirect_to help_path, alert: "Sorry, there are no system administrators available to contact at this time."
      else
        admins.each do |admin|
          UserMailer.send_help_email(admin, current_user, job, issue, expansion).deliver_later
        end
        return redirect_to help_path, notice: "Help request sent successfully, a system administrator will be in touch."
      end
    end
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
      UserMailer.with(email: current_user.email, role: role, comment: comment).send_sign_up_email.deliver_later
      redirect_to sign_up_path, notice: "Sign up email sent successfully!"
    end
  end

  private

    def authorize_pages
      case action_name
      when "help"
        authorize! :help, :pages
      when "send_help_email"
        authorize! :send_help_email, :pages
      when "sign_up"
        authorize! :sign_up, :pages
      when "send_sign_up_email"
        authorize! :send_sign_up_email, :pages
      end
    end

end
