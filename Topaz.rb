require 'Stone'

class Topaz
  def initialize(stone)
    fail "We expect the stone #{stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !stone.running?
    @stone = stone
    @commandWrapper = CommandWrapper.new("#{stone.logDirectory}/Topaz.log")
  end

  def commands(topazCommands)
    @commandWrapper.run("topaz -l", true, topazCommands)
  end

  def output
    @commandWrapper.output
  end
end
