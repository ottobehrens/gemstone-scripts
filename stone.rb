require 'CommandWrapper'
require 'Topaz'

class GemStone

  def self.current
    self.new("/opt/gemstone/product")
  end

  def initialize(installation_path)
    @installation_path = installation_path

    ENV['GEMSTONE'] = @installation_path
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
  end

  def stones
    Dir.glob("#{config_directory}/*").collect do | full_filename |
      File.basename(full_filename).split(".").first 
    end
  end

  def status
    system("gslist -clv")
  end


  def stopnetldi
    system("stopnetldi")
  end

  def startnetldi
    system("startnetldi -g")
  end

  def initial_extent
    File.join(@installation_path, "bin", "extent0.dbf")
  end

  def installation_extent_directory
    "/var/local/gemstone"
  end

  def installation_path
    @installation_path
  end

  def config_directory
    "/etc/gemstone"
  end
end

class Stone
  attr_reader :name, :user_name, :password

  def Stone.existing(name)
    fail "Stone does not exist" if not GemStone.current.stones.include? name
    Stone.new(name, GemStone.current)
  end

  def Stone.create(name)
    fail "Cannot create stone #{name}: the conf file already exists in /etc/gemstone" if GemStone.current.stones.include? name
    instance = Stone.new(name, GemStone.current)
    instance.initialize_new_stone
    instance
  end

  def initialize(name, gemstone_environment)
    @name = name
    @command_runner = CommandWrapper.new("#{log_directory}/Stone.log")
    @topaz_runner = Topaz.new(self)

    initialize_gemstone_environment(gemstone_environment)
  end

  def initialize_gemstone_environment(gemstone_environment)
    @gemstone_environment = gemstone_environment ||= GemStone.current

    ENV['GEMSTONE_NAME'] = @name
    ENV['GEMSTONE_LOGDIR'] = log_directory
    ENV['GEMSTONE_DATADIR'] = data_directory
  end

  def initialize_new_stone
    create_config_file
    mkdir_p log_directory
    mkdir_p extent_directory
    mkdir_p tranlog_directories
    initialize_extents
  end

  def running?(waitTime = -1)
    0 == @command_runner.run("waitstone #@name #{waitTime}", false)
  end

  def status
    if running?
      sh "gslist -clv #@name"
    else
      puts "#@name not running"
    end
  end

  def start
    @command_runner.run("startstone -z #{system_config_filename} -l #{File.join(log_directory, @name)}.log #{@name}")
    running?(10)
    self
  end

  def stop
    @command_runner.run("stopstone -i #@name DataCurator swordfish")
    self
  end

  def restart
    stop
    start
  end

  def backup
    result = @topaz_runner.commands("SystemRepository startNewLog")
    tranlog_number = (/(\d*)$/.match(result))[1]

    @topaz_runner.commands("SystemRepository startCheckpointSync")
    @topaz_runner.commands("System abortTransaction. SystemRepository fullBackupCompressedTo: '#{extend_backup_filename}'")

    @command_runner.run("tar zcf #{backup_filename} #{extend_backup_filename} #{data_directory}/tranlog/tranlog#{tranlog_number}.dbf")
  end

  def system_config_filename
    "#{@gemstone_environment.config_directory}/#@name.conf"
  end

  def create_config_file
    require 'erb'
    File.open(system_config_filename, "w") do | file |
      file.write(ERB.new(File.open("stone.conf.template").readlines.join).result(binding))
    end
    self
  end

  def user_name
    "DataCurator"
  end

  def password
    "swordfish"
  end

  def extent_directory
    File.join(data_directory, "extent")
  end

  def extent_filename
    File.join(extent_directory, "extent0.dbf")
  end

  def scratch_directory
    File.join(data_directory, "scratch")
  end

  def tranlog_directories
    directory = File.join(data_directory, "tranlog")
    [directory, directory]
  end

  def log_directory
    "/var/log/gemstone/#{@name}"
  end

  def data_directory
    "/var/local/gemstone/#@name"
  end

  def backup_directory
    "/var/local/backups"
  end

  def backup_filename
    "#{backup_directory}/#{name}_#{Date.today.strftime('%F')}.bak.tgz"
  end

  def extend_backup_filename
    "#{backup_directory}/#{name}_#{Date.today.strftime('%F')}.full.gz"
  end

  private

  def initialize_extents
    install(@gemstone_environment.initial_extent, extent_filename, :mode => 0660)
  end

end
