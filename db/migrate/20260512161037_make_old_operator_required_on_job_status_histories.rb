class MakeOldOperatorRequiredOnJobStatusHistories < ActiveRecord::Migration[8.0]
  def change
    change_column_null :job_status_histories, :old_operator_id, false
  end
end