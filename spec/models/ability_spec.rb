require 'rails_helper'
require 'cancan/matchers'

RSpec.describe Ability, type: :model do
  let(:client_user)   { create(:user, role: :client) }
  let(:operator_user) { create(:user, role: :operator) }
  let(:admin_user)    { create(:user, role: :admin) }
  let(:owner_user)    { create(:user, role: :owner) }
  let(:other_client)  { create(:user, role: :client) }

  let(:own_job)   { Job.create!(title: 'Own Job',   status: :pending, client: client_user) }
  let(:other_job) { Job.create!(title: 'Other Job', status: :pending, client: other_client) }

  describe 'unauthenticated user' do
    subject(:ability) { Ability.new(nil) }

    it { is_expected.not_to be_able_to(:read,    Job) }
    it { is_expected.not_to be_able_to(:create,  Job) }
    it { is_expected.not_to be_able_to(:manage,  Job) }
  end

  describe 'client' do
    subject(:ability) { Ability.new(client_user) }

    it { is_expected.to     be_able_to(:read, own_job) }
    it { is_expected.not_to be_able_to(:read, other_job) }
    it { is_expected.not_to be_able_to(:manage, own_job) }
    it { is_expected.to     be_able_to(:update, own_job) }
    it { is_expected.to     be_able_to(:cancel_job, own_job) }
    it { is_expected.not_to be_able_to(:cancel_job, other_job) }
    it { is_expected.not_to be_able_to(:update_status, own_job) }
    it { is_expected.not_to be_able_to(:complete_job, own_job) }
    it { is_expected.not_to be_able_to(:destroy, own_job) }
  end

  describe 'operator' do
    subject(:ability) { Ability.new(operator_user) }

    it { is_expected.to     be_able_to(:read, own_job) }
    it { is_expected.to     be_able_to(:read, other_job) }
    it { is_expected.not_to be_able_to(:manage, own_job) }
    it { is_expected.not_to be_able_to(:update, own_job) }
    it { is_expected.not_to be_able_to(:destroy, own_job) }
  end

  describe 'admin' do
    subject(:ability) { Ability.new(admin_user) }

    it { is_expected.to be_able_to(:manage, own_job) }
    it { is_expected.to be_able_to(:manage, other_job) }
    it { is_expected.to be_able_to(:update, own_job) }
    it { is_expected.to be_able_to(:update_status, own_job) }
    it { is_expected.to be_able_to(:update_status, other_job) }
    it { is_expected.to be_able_to(:destroy, own_job) }
  end

  describe 'owner' do
    subject(:ability) { Ability.new(owner_user) }

    it { is_expected.to be_able_to(:manage, own_job) }
    it { is_expected.to be_able_to(:manage, other_job) }
    it { is_expected.to be_able_to(:update, own_job) }
    it { is_expected.to be_able_to(:update_status, own_job) }
    it { is_expected.to be_able_to(:update_status, other_job) }
    it { is_expected.to be_able_to(:destroy, own_job) }
  end
end
