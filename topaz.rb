require 'stone'
require 'expect'

class Topaz
  attr_accessor :output

  def initialize(stone, topaz_command="topaz")
    @stone = stone
    @output = []
    @topaz_command = "#{topaz_command} 2>&1"
  end

  def commands(topaz_commands)
    fail "We expect the stone #{stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !@stone.running?
    IO.popen(@topaz_command, "w+") do |io|
      consume_until_prompt(io)
      topaz_commands.each do | command |
        io.puts command
        consume_until_prompt(io)
      end
    end
  end

  private

  def consume_until_prompt(io)
    if result = io.expect(/.*> $/)
      @output << result[0]
    end
  end
end
