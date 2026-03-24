class DropCancelledJobs < ActiveRecord::Migration[8.0]
  def change
    drop_table :cancelled_jobs
    drop_table :complete_jobs
  end
end
