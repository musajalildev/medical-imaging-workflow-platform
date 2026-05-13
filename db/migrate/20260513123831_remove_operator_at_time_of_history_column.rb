class RemoveOperatorAtTimeOfHistoryColumn < ActiveRecord::Migration[8.0]
  def change
    remove_reference :job_status_histories,
                     :operator_at_time_of_update,
                     foreign_key: { to_table: :users },
                     index: true
  end
end