class AddTypeColumnToNotification < ActiveRecord::Migration[8.0]
  def change
    add_column :notifications, :type, :integer
  end
end
