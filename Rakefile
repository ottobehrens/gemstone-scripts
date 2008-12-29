require 'Stone'

task :default => :status

desc "Create a new stone"
task :new_stone, :stone_name do |t, args|
  puts "Creating #{args.stone_name}"
  Stone.create(args.stone_name)
end

desc "Server status"
task :status do
  GemStone.status
end

GemStone.stones.each do |stoneName|
  namespace stoneName do
    stone = Stone.new(stoneName)

    desc "restart - #{stone}"
    task 'restart' do
      stone.restart
    end

    if stone.running?
      desc "stop - #{stone}"
      task 'stop' do |task|
        stone.stop
      end
    else
      desc "start - #{stone}"
      task 'start' do |task|
        stone.start
      end
    end
  end
end

