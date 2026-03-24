Dir[Rails.root.join("db/seeds/*.seeds.rb")].sort.each do |file|
  puts "Running seed:\e[31m #{File.basename(file)}\e[0m"
  load file
end
