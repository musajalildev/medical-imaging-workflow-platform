class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]

  
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

end
