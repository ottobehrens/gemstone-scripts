require 'stone'
require 'expect'

class TopazError < RuntimeError
  attr_accessor :exit_status, :output

  def to_s
    # Get the child's exit code
    puts @exit_status >> 8
    puts @output
  end

  def initialize(exit_status, output)
    @exit_status = exit_status
    @output = output
  end
end

class Topaz
  attr_accessor :output

  def initialize(stone, topaz_command="topazl")
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
    if $?.exitstatus > 0
      raise TopazError.new($?, @output)
    end
    return @output
  end

  private

  def consume_until_prompt(io)
    if result = io.expect(/(^.*> $)/)
      # remove prompt from output
      command_output = result[0].gsub(result[1], "")
      @output << command_output if not command_output.empty?
    end
  end
end
