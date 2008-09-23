class Stone
  def initialize(stoneName)
    ENV['GEMSTONE'] = "/usr/local/gemstone"
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
    @stoneName = stoneName
  end

  def isRunning(waitTime = -1)
    0 == run("waitstone #@stoneName #{waitTime}", false)
  end

  def systemConfFileName
    File.join('/etc/gemstone', @stoneName + '.conf')
  end

  def logDirectory
    File.join('/var/log/gemstone', @stoneName)
  end

  def start
    run("startstone -z #{systemConfFileName} -l #{File.join(logDirectory, @stoneName)}.log #{@stoneName}")
    isRunning(10)
  end

  def stop
    run("stopstone -i #@stoneName DataCurator swordfish")
  end

  def run(commandLine, failOnNonZeroExitValue=true)
    firstWord = /\w+/.match(commandLine)[0]
    puts("#{firstWord}...")
    output = ''
    IO.popen("#{commandLine} 2>&1") { | io | output = io.read }
    fail "\"#{commandLine}\" failed with exit code #{$?}\n#{output}" if $? != 0 and failOnNonZeroExitValue
    $?
  end
end
