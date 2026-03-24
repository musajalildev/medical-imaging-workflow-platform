class CreateCancelledJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :cancelled_jobs do |t|
      t.references :job, null: false, foreign_key: { to_table: :jobs }
      t.text :cancel_reason

      t.timestamps
    end
  end
end
