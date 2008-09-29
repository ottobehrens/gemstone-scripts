class Stone
  attr_reader :mostRecentOutput, :name

  def initialize(name)
    ENV['GEMSTONE'] = "/usr/local/gemstone"
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
    @name = name
    @mostRecentOutput = ''
  end

  def running?(waitTime = -1)
    0 == run("waitstone #@name #{waitTime}", false)
  end

  def systemConfFileName
    File.join('/etc/gemstone', @name + '.conf')
  end

  def logDirectory
    File.join('/var/log/gemstone', @name)
  end

  def start
    run("startstone -z #{systemConfFileName} -l #{File.join(logDirectory, @name)}.log #{@name}")
    running?(10)
  end

  def stop
    run("stopstone -i #@name DataCurator swordfish")
  end

  def restart
    stop
    start
  end

  def run(commandLine, failOnNonZeroExitValue=true)
    firstWord = /\w+/.match(commandLine)[0]
    puts("#{firstWord}...")
    commandLineStderrRedirected = "#{commandLine} 2>&1"
    result = doItNow(commandLineStderrRedirected)
    fail "\"#{commandLineStderrRedirected}\" failed with exit code #{result}\n#{@mostRecentOutput}" if result != 0 and failOnNonZeroExitValue
    result
  end

  def doItNow(commandLine)
    result = 1
    File.open("#{logDirectory}/Stone.log", "a") do |logFile| 
      logFile.sync = true
      logFile.write(commandLine + "\n")
      IO.popen(commandLine, "w+") do | io | 
        readOutput(io, logFile)
      end
      result = $?
    end
    result
  end

  def readOutput(io, logFile)
    @mostRecentOutput = ""
    begin
      line = io.gets
      if !line.nil? then 
        @mostRecentOutput += line
        logFile.write(line)
      end
    end until line.nil?
  end
end
