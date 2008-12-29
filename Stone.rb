require 'CommandWrapper'

class GemStone

  def initialize
    ENV['GEMSTONE'] = "/opt/gemstone/product"
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
  end

  def logDirectory
    "/var/log/gemstone/#{@name}"
  end

  def self.stones
    Stone.definedInstances
  end

  def self.status
    system("gslist -clv")
  end

  def self.start_netldi
  end
end

class Stone
  attr_reader :name

  def Stone.create(name)
    fail "Cannot create stone #{name}: the conf file already exists in /etc/gemstone" if Stone.definedInstances.include?(name)
    instance = Stone.new(name)
    instance.createConfFile
    instance.createLogDirectory
    instance
  end

  def Stone.definedInstances
    Dir.new('/etc/gemstone').inject([]) do | stones, fileName | 
      if /(\w+)\.conf$/ =~ fileName then 
	stones.push($1) 
      end 
      stones
    end
  end

  def initialize(name)
    ENV['GEMSTONE'] = "/opt/gemstone/product"
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
    @name = name
    @commandWrapper = CommandWrapper.new("#{logDirectory}/Stone.log")
  end

  def running?(waitTime = -1)
    0 == @commandWrapper.run("waitstone #@name #{waitTime}", false)
  end

  def systemConfFileName
    "/etc/gemstone/#{@name}.conf"
  end

  def createConfFile
    File.open(systemConfFileName, "w") do | file | file.write("conf") end
  end

  def logDirectory
    "/var/log/gemstone/#{@name}"
  end

  def createLogDirectory
    if !File.directory?(logDirectory) then Dir.mkdir(logDirectory) end
  end

  def start
    @commandWrapper.run("startstone -z #{systemConfFileName} -l #{File.join(logDirectory, @name)}.log #{@name}")
    running?(10)
  end

  def stop
    @commandWrapper.run("stopstone -i #@name DataCurator swordfish")
  end

  def restart
    stop
    start
  end

  def delete
    File.delete(systemConfFileName)
  end
end
