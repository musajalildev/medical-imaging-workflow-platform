class JobsController < ApplicationController
  def new
    @job = Job.new
  end

  def create
    @job = current_user.jobs.build(job_params)

    if @job.save
      # Dummy handling for now
      handle_uploaded_files(params[:job][:pdf], params[:job][:dicom])

      redirect_to root_path, notice: "Job created"
    else
      render :new
    end
  end

  private

  def job_params
    params.require(:job).permit(:title, :status)
  end

  def handle_uploaded_files(pdf_file, dicom_file)
    # Dummy function — does nothing for now
    Rails.logger.info "PDF received: #{pdf_file&.original_filename}"
    Rails.logger.info "DICOM received: #{dicom_file&.original_filename}"
  end
end