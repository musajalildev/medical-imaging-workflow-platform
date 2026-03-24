class CreateImageFiles < ActiveRecord::Migration[8.0]
  def change
    create_table :image_files do |t|
      t.references :job, null: false, foreign_key: { to_table: :jobs }
      t.string :file_path
      t.string :file_type

      t.timestamps
    end
  end
end
