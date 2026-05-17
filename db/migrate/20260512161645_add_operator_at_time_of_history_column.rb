class AddOperatorAtTimeOfHistoryColumn < ActiveRecord::Migration[8.0]
  def change
    add_reference :job_status_histories, :operator_at_time_of_update,
                  null: false,
                  foreign_key: { to_table: :users }
  end
end
