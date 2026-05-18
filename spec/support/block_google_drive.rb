RSpec.configure do |config|
  config.before(:each) do
    allow(Google::Apis::DriveV3::DriveService).to receive(:new) do
      raise "REAL GOOGLE DRIVE CALL BLOCKED BY TESTS"
    end
  end
end
