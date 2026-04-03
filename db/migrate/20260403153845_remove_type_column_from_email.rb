class RemoveTypeColumnFromEmail < ActiveRecord::Migration[8.0]
  def change
        remove_column :notifications, :type, :integer
  end
end
