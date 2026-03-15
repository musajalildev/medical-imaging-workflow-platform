class CompleteJobsController < ApplicationController
  before_action :set_complete_job, only: %i[ show edit update destroy ]

  # GET /complete_jobs
  def index
    @complete_jobs = CompleteJob.all
  end

  # GET /complete_jobs/1
  def show
  end

  # GET /complete_jobs/new
  def new
    @complete_job = CompleteJob.new
  end

  # GET /complete_jobs/1/edit
  def edit
  end

  # POST /complete_jobs
  def create
    @complete_job = CompleteJob.new(complete_job_params)

    if @complete_job.save
      redirect_to @complete_job, notice: "Complete job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /complete_jobs/1
  def update
    if @complete_job.update(complete_job_params)
      redirect_to @complete_job, notice: "Complete job was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /complete_jobs/1
  def destroy
    @complete_job.destroy!
    redirect_to complete_jobs_path, notice: "Complete job was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_complete_job
      @complete_job = CompleteJob.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def complete_job_params
      params.expect(complete_job: [ :job_id ])
    end
end
