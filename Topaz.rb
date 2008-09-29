require 'Stone'

class Topaz
  attr_reader :mostRecentOutput

  def initialize(stone)
    fail "We expect the stone #{stone.name} to be running if doing topaz commands. (Is this overly restrictive?)" if !stone.isRunning
    @stone = stone
    @mostRecentOutput = ''
  end

  def commands(topazCommands)
    puts("topaz...")
    commandLineStderrRedirected = "topaz -l 2>&1"
    result = doItNow(commandLineStderrRedirected, topazCommands)
    fail "\"#{commandLineStderrRedirected}\" failed with exit code #{result}\n#{@mostRecentOutput}" if result != 0 
    result
  end

  def doItNow(commandLine, topazCommands)
    result = 1
    File.open("#{@stone.logDirectory}/Stone.log", "a") do |logFile| 
      logFile.sync = true
      logFile.write(commandLine + "\n")
      IO.popen(commandLine, "w+") do | io | 
        readOutput(io, logFile)
        topazCommands.each do | command |
          writeIO(io, command, logFile)
          readOutput(io, logFile)
	end
        writeIO(io, "exit\n", logFile)
      end
      result = $?
    end
    result
  end

  def writeIO(io, input, logFile)
    selectArray = IO.select(nil, [io], nil, 5)
    fail "IO.select timed out on waiting to write to topaz." if selectArray.nil?
    logFile.write(input)
    io.write(input)
  end

  def readOutput(io, logFile, untilMatchString=/^topaz ?\d*> /)
    require 'stringio'
    lineIO = StringIO.new
    @mostRecentOutput = ""
    mostRecentOutputIO = StringIO.new(@mostRecentOutput)
    loop do
      selectArray = IO.select([io], nil, nil, 5)
      fail "IO.select timed out on waiting to read from topaz." if selectArray.nil?
      # if !selectArray.equal?(io) then 
      #   fail "Unexpected result from IO.select: selected on read only io \"#{io}\" and got something else \"#{selectArray}\"!" if !selectArray[0].equal?(io)
      # end
      char = io.getc
      if !char.nil? then
        mostRecentOutputIO.putc(char)
        lineIO.putc(char)
        logFile.putc(char)
        return if !untilMatchString.nil? and untilMatchString =~ lineIO.string
	if char == ?\n then
	  lineIO = StringIO.new
	end
      end
    end
  end
end
