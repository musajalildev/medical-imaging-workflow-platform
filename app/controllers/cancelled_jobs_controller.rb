class CancelledJobsController < ApplicationController
  before_action :set_cancelled_job, only: %i[ show edit update destroy ]

  # GET /cancelled_jobs
  def index
    @cancelled_jobs = CancelledJob.all
  end

  # GET /cancelled_jobs/1
  def show
  end

  # GET /cancelled_jobs/new
  def new
    @cancelled_job = CancelledJob.new
  end

  # GET /cancelled_jobs/1/edit
  def edit
  end

  # POST /cancelled_jobs
  def create
    @cancelled_job = CancelledJob.new(cancelled_job_params)

    if @cancelled_job.save
      redirect_to @cancelled_job, notice: "Cancelled job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /cancelled_jobs/1
  def update
    if @cancelled_job.update(cancelled_job_params)
      redirect_to @cancelled_job, notice: "Cancelled job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /cancelled_jobs/1
  def destroy
    @cancelled_job.destroy!
    redirect_to cancelled_jobs_path, notice: "Cancelled job was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cancelled_job
      @cancelled_job = CancelledJob.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def cancelled_job_params
      params.expect(cancelled_job: [ :job_id, :cancel_reason ])
    end
end
