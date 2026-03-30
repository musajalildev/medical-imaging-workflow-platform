class JobsController < ApplicationController
  load_and_authorize_resource

  # GET /jobs
  def index
    permitted = params.permit(:status, :search, :search_by, :sort)

    @jobs = @jobs.where(status: permitted[:status]) if permitted[:status].present?

    if permitted[:search].present?
      q = "%#{permitted[:search]}%"
      case permitted[:search_by]
      when 'title'
        @jobs = @jobs.where("jobs.title ILIKE :q", q: q)
      when 'client'
        @jobs = @jobs.joins(:client).where("users.givenname ILIKE :q OR users.sn ILIKE :q OR users.username ILIKE :q", q: q)
      when 'operator'
        @jobs = @jobs.joins("INNER JOIN users AS operators ON operators.id = jobs.operator_id")
                     .where("operators.givenname ILIKE :q OR operators.sn ILIKE :q OR operators.username ILIKE :q", q: q)
      else
        @jobs = @jobs.joins(:client).where("jobs.title ILIKE :q OR users.givenname ILIKE :q OR users.sn ILIKE :q OR users.username ILIKE :q", q: q)
      end
    end

    sort_dir = permitted[:sort] == 'asc' ? :asc : :desc
    @jobs = @jobs.order(created_at: sort_dir)
    @total_count = @jobs.count
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
    if @job.update(job_params)
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

    def authorize_job
      authorize! :manage, @job
    end

    # Only allow a list of trusted parameters through.
    def job_params
      params.expect(job: [ :client_id, :operator_id, :status, :title, :description ])
    end
end
