# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

if Rails.env.production?
	[
		{username: "aca24bdg", role: :owner, email: "bdgrassie1@sheffield.ac.uk", givenname: "Ben", sn: "D Grassie"},
		{username: "aca23ejw", role: :admin, email: "ejwood1@sheffield.ac.uk", givenname: "Ethan", sn: "Wood"},
		{username: "aca24iu", role: :admin, email: "iuteh-obuseh1@sheffield.ac.uk", givenname: "Ijeoma", sn: "Uteh-Obuseh"},
		{username: "aca24maj", role: :operator, email: "majalil1@sheffield.ac.uk", givenname: "Musa", sn: "A Jalil"},
		{username: "aca24ok", role: :operator, email: "okrasnovidov1@sheffield.ac.uk", givenname: "Alex", sn: "Krasnovidov"},
		{username: "acc24rj", role: 4, email: "rjones26@sheffield.ac.uk", givenname: "Ryan ", sn: "Jones"}

	].each do |attrs|
		User.find_or_create_by(email: attrs[:email]) do |u|
			u.assign_attributes(attrs)
		end
	end
	puts "Seeded #{User.count} users"

		[
		{ title: "MRI brain segmentation",       description: "Automated segmentation of 500 MRI brain scans using FreeSurfer.",                          status: :pending,     client: dev_client },
		{ title: "Genomic variant calling",       description: "Identify SNPs and indels across 300 patient whole-genome samples.",                        status: :assigned,    client: dev_client, operator: dev_operator },
		{ title: "Drug interaction simulation",   description: "Molecular docking simulation for candidate compounds against target protein.",             status: :in_progress, client: dev_client, operator: dev_operator },
		{ title: "CT scan batch processing",      description: "Process and reconstruct 1000 CT scans for lung nodule detection pipeline.",                status: :complete,    client: dev_client, operator: dev_operator },
		{ title: "Protein structure prediction",  description: "AlphaFold2 structure prediction for 50 novel disease-related proteins.",                   status: :cancelled,      client: dev_client },
		{ title: "Retinal image classification",  description: "Train CNN classifier on 10k retinal fundus images for diabetic retinopathy grading.",      status: :pending,     client: dev_client },
		{ title: "Pathology slide analysis",      description: "Whole-slide image tiling and feature extraction for tumour grading.",                      status: :in_progress, client: dev_client, operator: dev_operator },
	].each do |attrs|
		Job.find_or_create_by(title: attrs[:title], client: attrs[:client]) do |j|
			j.assign_attributes(attrs)
		end
	end
	puts "Seeded #{Job.count} dev jobs"
end

if Rails.env.development?
	[
		{ username: "dev_admin",    role: :admin,    givenname: "Dev",    sn: "Admin",    email: "dev_admin@example.com" },
		{ username: "dev_operator", role: :operator, givenname: "Dev",    sn: "Operator", email: "dev_operator@example.com" },
		{ username: "dev_client",   role: :client,   givenname: "Dev",    sn: "Client",   email: "dev_client@example.com" },
		{ username: "dev_owner",    role: :owner,    givenname: "Dev",    sn: "Owner",    email: "dev_owner@example.com" },
		{username: "aca24bdg", role: :owner, email: "bdgrassie1@sheffield.ac.uk", givenname: "Ben", sn: "D Grassie"},
		{username: "aca23ejw", role: :admin, email: "ejwood1@sheffield.ac.uk", givenname: "Ethan", sn: "Wood"},
		{username: "aca24iu", role: :admin, email: "iuteh-obuseh1@sheffield.ac.uk", givenname: "Ijeoma", sn: "Uteh-Obuseh"},
		{username: "aca24maj", role: :operator, email: "majalil1@sheffield.ac.uk", givenname: "Musa", sn: "A Jalil"},
		{username: "aca24ok", role: :operator, email: "okrasnovidov1@sheffield.ac.uk", givenname: "Alex", sn: "Krasnovidov"},
		{username: "acc24rj", role: :client, email: "rjones26@sheffield.ac.uk", givenname: "Ryan ", sn: "Jones"}
	].each do |attrs|
		User.find_or_create_by(username: attrs[:username]) do |u|
			u.assign_attributes(attrs)
		end
	end
	puts "Seeded #{User.count} dev users"

	dev_client   = User.find_by!(username: "dev_client")
	dev_operator = User.find_by!(username: "dev_operator")

	[
		{ title: "MRI brain segmentation",       description: "Automated segmentation of 500 MRI brain scans using FreeSurfer.",                          status: :pending,     client: dev_client },
		{ title: "Genomic variant calling",       description: "Identify SNPs and indels across 300 patient whole-genome samples.",                        status: :assigned,    client: dev_client, operator: dev_operator },
		{ title: "Drug interaction simulation",   description: "Molecular docking simulation for candidate compounds against target protein.",             status: :in_progress, client: dev_client, operator: dev_operator },
		{ title: "CT scan batch processing",      description: "Process and reconstruct 1000 CT scans for lung nodule detection pipeline.",                status: :complete,    client: dev_client, operator: dev_operator },
		{ title: "Protein structure prediction",  description: "AlphaFold2 structure prediction for 50 novel disease-related proteins.",                   status: :cancelled,      client: dev_client },
		{ title: "Retinal image classification",  description: "Train CNN classifier on 10k retinal fundus images for diabetic retinopathy grading.",      status: :pending,     client: dev_client },
		{ title: "Pathology slide analysis",      description: "Whole-slide image tiling and feature extraction for tumour grading.",                      status: :in_progress, client: dev_client, operator: dev_operator },
	].each do |attrs|
		Job.find_or_create_by(title: attrs[:title], client: attrs[:client]) do |j|
			j.assign_attributes(attrs)
		end
	end
	puts "Seeded #{Job.count} dev jobs"
end