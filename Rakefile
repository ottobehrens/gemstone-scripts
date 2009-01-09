require 'stone'

# Set to true to see what commands gets executed
verbose(false)

task :default do
  puts "Tasks for managing GemStone"
end

desc "Create a new stone"
task :new_stone, :stone_name do |t, args|
  puts "Creating #{args.stone_name}"
  Stone.create(args.stone_name)
end

desc "Server status"
task :status do
  GemStone.current.status
end

desc "Start netldi"
task :stopnetldi do
  GemStone.current.stopnetldi
end

desc "Start netldi"
task :startnetldi do
  GemStone.current.startnetldi
end

def task_gemstone(stone, action)
    desc "#{action.to_s} - #{stone.name}"
    task action do
      stone.send(action)
    end
end

GemStone.current.stones.each do |stoneName|
  namespace stoneName do
    stone = Stone.new(stoneName, GemStone.current)

    [:stop, :start, :restart, :status].each do |action|
      task_gemstone(stone, action)
    end
  end
end
