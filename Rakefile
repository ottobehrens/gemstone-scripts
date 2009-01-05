require 'stone'

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
  GemStone.status
end

def task_gemstone(stone, action)
    desc "#{action.to_s} - #{stone}"
    task action do
      stone.send(action)
    end
end

GemStone.current.stones.each do |stoneName|
  namespace stoneName do
    stone = Stone.new(stoneName, GemStone.current)

    task_gemstone(stone, :restart)
    task_gemstone(stone, :status)

    if stone.running?
      task_gemstone(stone, :stop)
    else
      task_gemstone(stone, :start)
    end
  end
end
