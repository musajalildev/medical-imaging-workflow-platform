# spec/models/user_spec.rb
# == Schema Information
#
# Table name: users
#
#  id                 :bigint           not null, primary key
#  account_type       :string
#  current_sign_in_at :datetime
#  current_sign_in_ip :string
#  dn                 :string
#  email              :string           default(""), not null
#  givenname          :string
#  last_sign_in_at    :datetime
#  last_sign_in_ip    :string
#  mail               :string
#  ou                 :string
#  role               :integer          default("unassigned"), not null
#  sign_in_count      :integer          default(0), not null
#  sn                 :string
#  uid                :string
#  username           :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_users_on_email     (email)
#  index_users_on_username  (username)
#
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
