class AddHistoryTypeAndOperatorInformationToStatusHistory < ActiveRecord::Migration[8.0]
  def change
    add_reference :job_status_histories, :old_operator,
                  null: true,
                  foreign_key: { to_table: :users }

    add_reference :job_status_histories, :new_operator,
                  null: true,
                  foreign_key: { to_table: :users }

    add_column :job_status_histories, :history_type, :integer, null: false, default: 0
  end
end
