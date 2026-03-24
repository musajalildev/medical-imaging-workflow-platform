class CreateJobStatusHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :job_status_histories do |t|
      t.references :job, null: false, foreign_key: { to_table: :jobs }
      t.integer :old_status
      t.integer :new_status
      t.references :initiator, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
