#!/usr/bin/ruby

class TopazError < RuntimeError
  attr_accessor :exit_status, :output

  def to_s
    # Get the child's exit code
    puts "Topaz Error encountered: "
    puts @exit_status >> 8
    puts @output
    puts "EOE"
  end

  def initialize(exit_status, output)
    @exit_status = exit_status
    @output = output
  end
end

class String
  def execute_on_topaz_stream(topaz_stream)
    topaz_stream.puts(self)
  end
end

class Array
  def execute_on_topaz_stream(topaz_stream)
    join("\n").execute_on_topaz_stream(topaz_stream)
  end

  def line(line_number)
    self[line_number]
  end
end

class Topaz
  attr_accessor :output

  def initialize(stone, topaz_command="topaz -l -T 300000")
    @stone = stone
    @topaz_command = "$GEMSTONE/bin/#{topaz_command} 2>&1"
    @output = []
  end

  def commands(topaz_commands_array, full_logfile)
    fail "We expect the stone #{@stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !@stone.running?
    @stone.initialize_gemstone_environment

    send_all_commands_to_topaz_and_exit(topaz_commands_array, full_logfile)

    if topaz_failed?
      raise_error_with_last_log
    else
      build_up_output_tuple(topaz_commands_array)
      return @output
    end
  end

  def topaz_failed?
    $?.exitstatus > 0
  end

  def send_all_commands_to_topaz_and_exit(topaz_commands_array, full_logfile)
    IO.popen(@topaz_command, "w+") do |io|
      log_everything_to(full_logfile, io)
      topaz_commands_array.each_with_index do | command, index |
        log_command_separately(index, io)
        command.execute_on_topaz_stream(io)
        pop_log_output(io)
      end
      "exit".execute_on_topaz_stream(io)
    end
  end

  def build_up_output_tuple(topaz_commands_array)
    0.upto(topaz_commands_array.size) do | index |
      @output << [topaz_commands_array[index], read_output_file(log_file_name(index))]
    end
  end

  def raise_error_with_last_log
    raise TopazError.new($?, File.read(@most_recent_log_file_name))
  end

  def log_everything_to(full_logfile, io)
    "output append #{full_logfile}".execute_on_topaz_stream(io)
  end

  def log_file_name(index)
    "#{@stone.log_directory}/topaz.#{index}.log"
  end

  def log_command_separately(index, io)
    @most_recent_log_file_name = log_file_name(index)
    File.delete @most_recent_log_file_name if File.exist? @most_recent_log_file_name
    "output push #{@most_recent_log_file_name}".execute_on_topaz_stream(io)
  end

  def pop_log_output(io)
    "output pop".execute_on_topaz_stream(io)
  end

  def read_output_file(name)
    return [] if not File.exist? name
    lines = File.readlines(name)
    fail "expected #{lines.last} to be 'output pop' or 'Logging out' or 'exit' in file named #{name}" if not match_expected(lines)
    lines[0..-2]
  end

  def match_expected(lines)
    !lines.empty? and lines.last.match(/topaz( \d)?> (output pop|exit)|^Logging out session/)
  end

  def dump_as_script(*topaz_commands)
    topaz_commands.each do | command |
      command.execute_on_topaz_stream(STDOUT)
    end
    self
  end

end
