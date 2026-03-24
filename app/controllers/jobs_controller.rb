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
      attach_uploaded_file(@job, ensure_placeholders: true)
      redirect_to @job, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /jobs/1
  def update
    if @job.update(job_params)
      attach_uploaded_file(@job, ensure_placeholders: false)
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
      params.expect(job: [ :client_id, :operator_id, :status, :title, :description ])
    end

    def attach_uploaded_file(job, ensure_placeholders: false)
      uploaded_files = JSON.parse(params[:uploaded_files_json].presence || "[]")
      if uploaded_files.blank?
        if ensure_placeholders
          2.times { job.image_files.create!(file_path: nil, file_type: nil) }
        end
        return
      end

      uploaded_files.first(2).each do |uploaded|
        file_id = uploaded["file_id"].presence
        file_url = uploaded["file_url"].presence
        file_path = file_url.presence || (file_id.present? ? "https://drive.google.com/file/d/#{file_id}/view" : nil)
        file_type = uploaded["file_type"].presence

        image_file = job.image_files.build
        image_file.file_path = file_path
        image_file.file_type = file_type
        image_file.save!
      end

      if ensure_placeholders && uploaded_files.length < 2
        (2 - uploaded_files.length).times { job.image_files.create!(file_path: nil, file_type: nil) }
      end
    rescue JSON::ParserError
      if ensure_placeholders
        2.times { job.image_files.create!(file_path: nil, file_type: nil) }
      end
    end
end
