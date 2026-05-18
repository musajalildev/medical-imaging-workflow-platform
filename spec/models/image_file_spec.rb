# == Schema Information
#
# Table name: image_files
#
#  id         :bigint           not null, primary key
#  file_path  :string           not null
#  file_type  :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  job_id     :bigint           not null
#
# Indexes
#
#  index_image_files_on_job_id  (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (job_id => jobs.id)
#
# spec/models/image_file_spec.rb
require "rails_helper"

RSpec.describe ImageFile, type: :model do
  it "defines the ImageFile class" do
    expect(described_class.name).to eq("ImageFile")
  end
end