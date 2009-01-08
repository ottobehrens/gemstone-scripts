require 'stone'
require 'expect'

class Topaz
  attr_accessor :output
  def initialize(stone)
    @stone = stone
    @output = []
  end

  def run(run_expression)
    commands("run\n#{run_expression}\n%\n")
  end

  def commands(topaz_commands)
    fail "We expect the stone #{stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !@stone.running?
    IO.popen("topaz 2>&1", "w+") do |io|
      consume_until_prompt(io)
      topaz_commands.each do | command |
        io.write "#{command}\n"
        consume_until_prompt(io)
      end
    end
  end

  private

  def consume_until_prompt(io)
    result = io.expect(/.*>$/)
    if result
      @output << result[0]
      result
    end
  end
end
