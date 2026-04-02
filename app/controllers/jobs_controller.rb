class JobsController < ApplicationController
  before_action :set_job, only: %i[ show edit update destroy cancel_job ]

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
    updated_params = job_params

    # normalize custom status
    updated_params[:custom_status] = updated_params[:custom_status]&.strip

    # clear custom status if status is changed to non-custom
    if updated_params[:status] != "custom"
      updated_params[:custom_status] = nil
    end

    old_status = @job.get_status
    new_status = updated_params[:status] == "custom" ? updated_params[:custom_status] : updated_params[:status]

    # create a job status history record if the status is changing
    if old_status != new_status
      JobStatusHistory.create!(
        job: @job,
        old_status: @job.get_status,
        new_status: new_status,
        initiator: current_user
      )
    end

    if @job.update(updated_params)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      render :show, status: :unprocessable_entity
    end
  end

  # PATCH /jobs/1/cancel_job
  def cancel_job
    if @job.update(status: :cancelled)
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
