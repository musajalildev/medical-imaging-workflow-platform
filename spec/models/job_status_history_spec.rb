# == Schema Information
#
# Table name: job_status_histories
#
#  id           :bigint           not null, primary key
#  new_status   :integer
#  old_status   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  initiator_id :bigint           not null
#  job_id       :bigint           not null
#
# Indexes
#
#  index_job_status_histories_on_initiator_id  (initiator_id)
#  index_job_status_histories_on_job_id        (job_id)
#
# Foreign Keys
#
#  fk_rails_...  (initiator_id => users.id)
#  fk_rails_...  (job_id => jobs.id)
#
require 'rails_helper'

RSpec.describe JobStatusHistory, type: :model do
  pending "add some examples to (or delete) #{__FILE__}"
end
