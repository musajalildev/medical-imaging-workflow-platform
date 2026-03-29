# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

client = User.find_or_create_by!(email: 'client@example.com') do |u|
  u.role = :client
  u.username = 'client_user'
end

operator = User.find_or_create_by!(email: 'operator@example.com') do |u|
  u.role = :operator
  u.username = 'operator_user'
end

Job.create!([
  { title: 'MRI brain segmentation', description: 'Automated segmentation of 500 MRI brain scans using FreeSurfer.', status: :pending, client: client },
  { title: 'Genomic variant calling', description: 'Identify SNPs and indels across 300 patient whole-genome samples.', status: :assigned, client: client, operator: operator },
  { title: 'Drug interaction simulation', description: 'Molecular docking simulation for candidate compounds against target protein.', status: :in_progress, client: client, operator: operator },
  { title: 'CT scan batch processing', description: 'Process and reconstruct 1000 CT scans for lung nodule detection pipeline.', status: :complete, client: client, operator: operator },
  { title: 'Protein structure prediction', description: 'AlphaFold2 structure prediction for 50 novel disease-related proteins.', status: :failed, client: client },
])
