class ChangeStatusToStringInStatusHistories < ActiveRecord::Migration[8.0]
  def change
    change_column :job_status_histories, :old_status, :string
    change_column :job_status_histories, :new_status, :string
  end
end
