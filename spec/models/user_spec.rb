# spec/models/user_spec.rb
require "rails_helper"

RSpec.describe User, type: :model do
  describe "roles" do

    it "supports client role" do
      user = create(:user, role: :client)
      expect(user.client?).to be(true)
    end

    it "supports operator role" do
      user = create(:user, role: :operator)
      expect(user.operator?).to be(true)
    end

    it "supports admin role" do
      user = create(:user, role: :admin)
      expect(user.admin?).to be(true)
    end

    it "supports owner role" do
      user = create(:user, role: :owner)
      expect(user.owner?).to be(true)
    end
  end
end