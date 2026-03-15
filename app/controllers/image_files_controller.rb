class ImageFilesController < ApplicationController
  before_action :set_image_file, only: %i[ show edit update destroy ]

  # GET /image_files
  def index
    @image_files = ImageFile.all
  end

  # GET /image_files/1
  def show
  end

  # GET /image_files/new
  def new
    @image_file = ImageFile.new
  end

  # GET /image_files/1/edit
  def edit
  end

  # POST /image_files
  def create
    @image_file = ImageFile.new(image_file_params)

    if @image_file.save
      redirect_to @image_file, notice: "Image file was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /image_files/1
  def update
    if @image_file.update(image_file_params)
      redirect_to @image_file, notice: "Image file was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /image_files/1
  def destroy
    @image_file.destroy!
    redirect_to image_files_path, notice: "Image file was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_image_file
      @image_file = ImageFile.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def image_file_params
      params.expect(image_file: [ :job_id, :file_path, :file_type ])
    end
end
