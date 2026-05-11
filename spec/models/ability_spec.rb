require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability do
  subject(:ability) { Ability.new(user) }

  let(:client_user) { create(:user, role: :client) }
  let(:operator_user) { create(:user, role: :operator) }
  let(:admin_user) { create(:user, role: :admin) }
  let(:owner_user) { create(:user, role: :owner) }

  let(:other_client) { create(:user, role: :client) }

  let(:own_job) do
    create(:job,
      title: "Own Job",
      description: "Test",
      status: :pending,
      client: client_user
    )
  end

  let(:other_job) do
    create(:job,
      title: "Other Job",
      description: "Test",
      status: :pending,
      client: other_client
    )
  end

  describe "client abilities" do
    let(:user) { client_user }

    it "can read own jobs" do
      expect(ability).to be_able_to(:read, own_job)
    end

    it "cannot read others jobs" do
      expect(ability).not_to be_able_to(:read, other_job)
    end

    it "can create jobs" do
      expect(ability).to be_able_to(:create, Job)
    end

    it "can update own jobs" do
      expect(ability).to be_able_to(:update, own_job)
    end
  end

  describe "operator abilities" do
    let(:user) { operator_user }

    it "can read jobs" do
      expect(ability).to be_able_to(:read, other_job)
    end

    it "can self assign jobs" do
      expect(ability).to be_able_to(:self_assign, other_job)
    end

    it "cannot update job not assigned to them" do
      expect(ability).not_to be_able_to(:update_status, other_job)
    end
  end

  describe "admin abilities" do
    let(:user) { admin_user }

    it "can manage all jobs" do
      expect(ability).to be_able_to(:manage, own_job)
      expect(ability).to be_able_to(:manage, other_job)
    end
  end

  describe "owner abilities" do
    let(:user) { owner_user }

    it "can manage all jobs" do
      expect(ability).to be_able_to(:manage, own_job)
      expect(ability).to be_able_to(:manage, other_job)
    end
  end
end