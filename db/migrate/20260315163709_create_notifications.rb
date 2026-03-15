class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: {to_table: :users}
      t.text :body
      t.boolean :is_read

      t.timestamps
    end
  end
end
