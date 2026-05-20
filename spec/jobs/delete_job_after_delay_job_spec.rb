require "rails_helper"

RSpec.describe DeleteJobAfterDelayJob, type: :job do
  let!(:job) { create(:job, title: "Some Title") }

  describe "perform" do
    context "when job is cancelled" do
      it "destroys the job and logs correct message" do
        before_jobs_count = Job.all.count

        expect(Rails.logger).to receive(:info).with("Begun deletion sequence for cancelled job_id: #{job.id}")
        expect { DeleteJobAfterDelayJob.new(job.id, "cancelled").perform }.to change(Job, :count).by(-1)
      end
    end
    
    context "when job is completed" do
      it "destroys the job and logs correct message" do
        before_jobs_count = Job.all.count

        expect(Rails.logger).to receive(:info).with("Begun deletion sequence for completed job_id: #{job.id}")
        expect { DeleteJobAfterDelayJob.new(job.id, "complete").perform }.to change(Job, :count).by(-1)
      end
    end
  end

  describe "rename_job" do
    it "adds 'Deleted Job - ' to the start of the jobs title" do
      DeleteJobAfterDelayJob.new(job.id, "complete").send(:rename_job, job)

      expect(job.title).to eq("Deleted Job - Some Title")
    end
  end
end