class CreateCompleteJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :complete_jobs do |t|
      t.references :job, null: false, foreign_key: { to_table: :jobs }

      t.timestamps
    end
  end
end
