class JobsController < ApplicationController
  before_action :set_job, only: %i[ show edit update destroy ]

  # GET /jobs
  def index
    @jobs = Job.all
  end

  # GET /jobs/1
  def show
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

    # clear custom status if status is changed to non-custom
    if updated_params[:status] != "custom"
      updated_params[:custom_status] = nil
    end

    # create a job status history record if the status is changing
    if @job.status != updated_params[:status] || @job.custom_status != updated_params[:custom_status]
      JobStatusHistory.create!(
        job: @job,
        old_status: @job.get_status,
        new_status: updated_params[:status] == "custom" ? updated_params[:custom_status] : updated_params[:status],
        initiator: current_user
      )
    end

    if @job.update(updated_params)
      redirect_to @job, notice: "Job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
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
      params.expect(job: [ :operator_id, :status, :title, :description, :custom_status ])
    end
end
