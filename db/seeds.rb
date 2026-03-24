# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
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