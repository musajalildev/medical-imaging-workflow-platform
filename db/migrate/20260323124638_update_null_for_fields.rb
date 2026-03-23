class UpdateNullForFields < ActiveRecord::Migration[8.0]
  def change
    change_column_null(:image_files, :file_path, false)
    change_column_null(:image_files, :file_type, false)
    change_column_null(:job_status_histories, :old_status, false)
    change_column_null(:job_status_histories, :new_status, false)
    change_column_null(:jobs, :title, false)
    change_column_null(:jobs, :status, false)
    change_column_null(:notifications, :body, false)
    change_column_null(:notifications, :is_read, false)
    change_column_default(:notifications, :is_read, from: nil, to: false)
    change_column_null(:jobs, :operator_id, true)
    change_column_null(:reports, :file_path, false)
  end
end
