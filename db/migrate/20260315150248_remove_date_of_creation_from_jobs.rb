class RemoveDateOfCreationFromJobs < ActiveRecord::Migration[8.0]
  def change
    remove_column :jobs, :date_of_creation, :datetime
  end
end
