class CommandWrapper
  attr_reader :output

  def initialize(logFileName)
    @logFileName = logFileName
    @output = []
  end

  def run(commandLine, failOnNonZeroExitValue=true, inputCommands=[])
    firstWord = /\w+/.match(commandLine)[0]
    puts("#{firstWord}...")
    commandLineStderrRedirected = "#{commandLine} 2>&1"
    result = doItNow(commandLineStderrRedirected, inputCommands)
    fail "\"#{commandLineStderrRedirected}\" failed with exit code #{result}\n#{@output[-1]}" if result != 0 and failOnNonZeroExitValue
    result
  end

  def doItNow(commandLine, inputCommands)
    result = 1
    File.open(@logFileName, "a") do |logFile| 
      logFile.sync = true
      logFile.write(commandLine + "\n")
      IO.popen(commandLine, "w+") do | io | 
        inputCommands.each do | command |
          readOutput(io, logFile)
          writeCommand(io, command, logFile)
	end
        readOutput(io, logFile)
      end
      result = $?
    end
    result
  end

  def writeCommand(io, command, logFile)
    selectArray = IO.select(nil, [io], nil, 5)
    fail "IO.select timed out on waiting to write." if selectArray.nil?
    logFile.write(command)
    io.write(command)
    if command[-1] != ?\n then
      logFile.write("\n")
      io.write("\n")
    end
  end

  def readOutput(io, logFile, untilMatchString=/^topaz ?\d*> /)
    require 'stringio'
    lineIO = StringIO.new
    output.push("")
    mostRecentOutputIO = StringIO.new(output[-1])
    loop do
      selectArray = IO.select([io], nil, nil, 20)
      fail "IO.select timed out on waiting to read." if selectArray.nil?
      char = io.getc
      if char.nil? then return end
      mostRecentOutputIO.putc(char)
      lineIO.putc(char)
      logFile.putc(char)
      return if untilMatchString =~ lineIO.string
      if char == ?\n then
	lineIO = StringIO.new
      end
    end
  end
end
