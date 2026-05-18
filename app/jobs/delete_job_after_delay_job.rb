class DeleteJobAfterDelayJob < Struct.new(:job_id, :status)
  def perform
    if status == "cancelled"
      job = Job.find_by(id: job_id)
      return unless job
      job.destroy!
      Rails.logger.info "Begun deletion sequence for cancelled job_id: #{job_id}"
    elsif status == "complete"
      completed_job = Job.find_by(id: job_id)
      completed_job.destroy! if completed_job.present?
      Rails.logger.info "Begun deletion sequence for completed job_id: #{job_id}"
    end
  end

  private

  def rename_job(job)
    job.title = "Deleted Job - #{job.title}"
    job.save!(validate: false)
  end
end
