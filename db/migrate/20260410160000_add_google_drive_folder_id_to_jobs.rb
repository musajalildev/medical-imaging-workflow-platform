class AddGoogleDriveFolderIdToJobs < ActiveRecord::Migration[8.0]
  def change
    add_column :jobs, :google_drive_folder_id, :string
  end
end
