class JobStatusHistoriesController < ApplicationController
  before_action :set_job_status_history, only: %i[ show edit update destroy ]

  # GET /job_status_histories
  def index
    @job_status_histories = JobStatusHistory.all
  end

  # GET /job_status_histories/1
  def show
  end

  # GET /job_status_histories/new
  def new
    @job_status_history = JobStatusHistory.new
  end

  # GET /job_status_histories/1/edit
  def edit
  end

  # POST /job_status_histories
  def create
    @job_status_history = JobStatusHistory.new(job_status_history_params)

    if @job_status_history.save
      redirect_to @job_status_history, notice: "Job status history was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /job_status_histories/1
  def update
    if @job_status_history.update(job_status_history_params)
      redirect_to @job_status_history, notice: "Job status history was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /job_status_histories/1
  def destroy
    @job_status_history.destroy!
    redirect_to job_status_histories_path, notice: "Job status history was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_job_status_history
      @job_status_history = JobStatusHistory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def job_status_history_params
      params.expect(job_status_history: [ :job_id, :old_status, :new_status, :initiator_id ])
    end
end
