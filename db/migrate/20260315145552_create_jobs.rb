class CreateJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :jobs do |t|
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :operator, null: false, foreign_key: { to_table: :users }
      t.integer :status
      t.string :title
      t.text :description
      t.datetime :date_of_creation

      t.timestamps
    end
  end
end
