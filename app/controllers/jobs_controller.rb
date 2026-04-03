class JobsController < ApplicationController
  before_action :set_job, only: %i[ show edit update destroy complete_job update_status cancel_job ]

  # GET /jobs
  def index
    @jobs = Job.all
  end

  # GET /jobs/1
  def show
    @user = current_user
  end

  # GET /jobs/new
  def new
    @job = Job.new
  end

  # GET /jobs/1/edit
  def edit
  end

  # POST /jobs
  def create
    @job = Job.new(job_params)

    if @job.save
      redirect_to @job, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update(job_params)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/update_status
  def update_status

    updated_params = job_params

    # normalize custom status
    updated_params[:custom_status] = updated_params[:custom_status]&.strip

    # clear custom status if status is changed to non-custom
    if updated_params[:status] != "custom"
      updated_params[:custom_status] = nil
    end

    # save old and new status for creating job status history record after update
    old_status = @job.get_status_for_display
    # returns humanized version of custom status if status is custom, otherwise returns humanized version of status enum
    new_status = (updated_params[:status] == "custom" ? updated_params[:custom_status] : updated_params[:status]).to_s.humanize

    if @job.update(updated_params)
      
      # create a job status history record if the status is changing
      if old_status != new_status
        JobStatusHistory.create!(
          job: @job,
          old_status: old_status,
          new_status: new_status,
          initiator: current_user
        )
        # send email to client if job status changed
        UserMailer.send_job_status_change_email(@job).deliver_later
      end

      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      redirect_to @job, status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/complete_job
  def complete_job
    if @job.update(status: :complete)
      UserMailer.send_job_completed_email(@job).deliver_later
      redirect_to @job, notice: "Job was successfully completed.", status: :see_other
    else
      redirect_to @job, alert: "Failed to complete job.", status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/cancel_job
  def cancel_job
    if @job.update(status: :cancelled)
      UserMailer.send_job_cancelled_email(@job).deliver_later
      redirect_to @job, notice: "Job was successfully cancelled.", status: :see_other
    else
      redirect_to @job, alert: "Failed to cancel job.", status: :unprocessable_entity
    end
  end

  # DELETE /jobs/1
  def destroy
    @job.destroy!
    redirect_to jobs_path, notice: "Job was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_job
      @job = Job.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def job_params
      params.expect(job: [ :status, :custom_status ])
    end
end
