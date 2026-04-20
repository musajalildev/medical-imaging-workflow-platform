class JobsController < ApplicationController
  load_and_authorize_resource

  # GET /jobs
  def index
    # Checks for operator role
    if current_user&.operator?
      @tab = params[:tab].presence_in(%w[assigned unassigned]) || "assigned"
      if @tab == "unassigned"
        @jobs = Job.where(operator_id: nil)
      else
        @jobs = Job.where(operator_id: current_user.id)
      end
    end

    permitted = params.permit(:status, :search, :search_by, :sort, :_method, :authenticity_token, :tab)

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

  # PATCH /jobs/1/self_assign
  def self_assign
    puts "hello"
    if @job.operator_id.nil?
      @job.update!(operator: current_user, status: :assigned)
      # Automatically update job status when assigned
      JobStatusHistory.create!(
        job: @job,
        old_status: @job.status_before_last_save || "pending",
        new_status: "assigned",
        initiator: current_user
      ) if @job.saved_change_to_operator_id?
      redirect_to jobs_path(tab: "unassigned"), notice: "Job assigned to you.", status: :see_other
    else
      redirect_to jobs_path(tab: "unassigned"), alert: "Job is already assigned.", status: :see_other
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

    def authorize_job
      authorize! :manage, @job
    end

    # Only allow a list of trusted parameters through.
    def job_params
      params.expect(job: [ :status, :custom_status ])
    end
end
