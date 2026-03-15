class CreateReports < ActiveRecord::Migration[8.0]
  def change
    create_table :reports do |t|
      t.references :job, null: false, foreign_key: { to_table: :jobs }
      t.string :file_path

      t.timestamps
    end
  end
end
