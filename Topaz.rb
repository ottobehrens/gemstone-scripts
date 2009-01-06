require 'stone'

class Topaz
  def initialize(stone)
    @stone = stone
    @commandWrapper = CommandWrapper.new("#{stone.log_directory}/Topaz.log")
  end

  def run(run_expression)
    commands("run\n#{run_expression}\n")
  end

  def commands(topaz_commands)
    fail "We expect the stone #{stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !@stone.running?
    wrapped = [
        "output append #{log_file}",
        "set u #{@stone.user_name} p #{@stone.password} gemstone #{@stone.name}",
        "login",
        "limit oops 100",
        "limit bytes 1000",
        "display oops",
        "iferror stack",
        topaz_commands,
        "output pop",
        "exit"
    ]
    @commandWrapper.run("topaz -l", true, wrapped.flatten)
  end

  def log_file
    "/tmp/topaz.log"
  end

  def output
    @commandWrapper.output
  end
end
