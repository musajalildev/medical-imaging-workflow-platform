require "faker"

def generate_username(first_name, last_name)
  letters   = Array('a'..'z').sample(3).join
  number    = rand(10..90)
  initials  = "#{first_name[0]}#{last_name[0]}".downcase

  "#{letters}#{number}#{initials}"
end

def generate_email(first_name, last_name)
  base = "#{first_name[0]}#{last_name}".downcase

  # 50% chance of adding a number 1–30
  number = rand < 0.5 ? "" : rand(1..30).to_s

  "#{base}#{number}@seedfield.ac.uk"
end

def create_seed_user
  first = Faker::Name.first_name
  last  = Faker::Name.last_name

  username = generate_username(first, last)
  email    = generate_email(first, last)

  # Ensure uniqueness for username + email
  while User.exists?(username: username)
    username = generate_username(first, last)
  end

  while User.exists?(email: email)
    email = generate_email(first, last)
  end

  User.create!(
    username: username,
    email: email,
    role: :unassigned
  )
end

# Seed N users
puts "\e[32m -Removing\e[0m previously seeded users..."
User.where("email LIKE ?", "%@seedfield.ac.uk").delete_all

N = 100
N.times { create_seed_user }
puts " -Created \e[32m#{N}\e[0m users."
