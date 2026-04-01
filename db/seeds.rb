# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

if Rails.env.development?
	[
		{ username: "dev_admin",    role: :admin,    givenname: "Dev",    sn: "Admin",    email: "dev_admin@example.com" },
		{ username: "dev_operator", role: :operator, givenname: "Dev",    sn: "Operator", email: "dev_operator@example.com" },
		{ username: "dev_client",   role: :client,   givenname: "Dev",    sn: "Client",   email: "dev_client@example.com" },
		{ username: "dev_owner",    role: :owner,    givenname: "Dev",    sn: "Owner",    email: "dev_owner@example.com" },
	].each do |attrs|
		User.find_or_create_by(username: attrs[:username]) do |u|
			u.assign_attributes(attrs)
		end
	end
	puts "Seeded #{User.count} dev users"
end

client = User.create(email: "client@example.com")
operator = User.create(email: "operator@example.com")

job = Job.create(
  client: client,
  operator: operator,
  title: "Test Job",
  description: "This is a test job.",
  status: :complete
)

JobStatusHistory.create(
  job: job,
  old_status: :pending,
  new_status: :assigned,
  initiator: operator
)

JobStatusHistory.create(
  job: job,
  old_status: :assigned,
  new_status: :in_progress,
  initiator: operator
)

JobStatusHistory.create(
  job: job,
  old_status: :in_progress,
  new_status: :complete,
  initiator: operator
)