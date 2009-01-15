require 'topaz'

class GemStoneInstallation

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
    sh "gslist -clv"
  end


  def stopnetldi
    sh "stopnetldi"
  end

  def startnetldi
    sh "startnetldi -g"
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
    fail "Stone does not exist" if not GemStoneInstallation.current.stones.include? name
    new(name, GemStoneInstallation.current)
  end

  def Stone.create(name)
    fail "Cannot create stone #{name}: the conf file already exists in /etc/gemstone" if GemStoneInstallation.current.stones.include? name
    instance = new(name, GemStoneInstallation.current)
    instance.initialize_new_stone
    instance
  end

  def initialize(name, gemstone_environment)
    @name = name
    initialize_gemstone_environment(gemstone_environment)
  end

  def initialize_gemstone_environment(gemstone_environment)
    @gemstone_environment = gemstone_environment ||= GemStoneInstallation.current

    ENV['GEMSTONE_NAME'] = @name
    ENV['GEMSTONE_LOGDIR'] = log_directory
    ENV['GEMSTONE_DATADIR'] = data_directory
  end

  # Bare bones stone with nothing loaded
  def initialize_new_stone
    create_config_file
    mkdir_p extent_directory
    mkdir_p log_directory
    mkdir_p tranlog_directories
    initialize_extents
  end

  # Will remove everything in the stone's data directory!
  def destroy!
    fail "Can not destroy a running stone" if running?
    rm_rf system_config_filename
    rm_rf extent_directory
    rm_rf log_directory
    rm_rf tranlog_directories
  end

  def running?(wait_time = -1)
    sh "waitstone #@name #{wait_time} 1>/dev/null" do | ok, status |
      return ok
    end
  end

  def status
    if running?
      sh "gslist -clv #@name"
    else
      puts "#@name not running"
    end
  end

  def start
    log_sh "startstone -z #{system_config_filename} -l #{File.join(log_directory, @name)}.log #{@name}"
    running?(10)
    self
  end

  def stop
    log_sh "stopstone -i #@name DataCurator swordfish"
    self
  end

  def restart
    stop
    start
  end

  def backup
    result = run_topaz_command("SystemRepository startNewLog")
    tranlog_number = (/(\d*)$/.match(result.last))[1]

    run_topaz_command("System startCheckpointSync")
    run_topaz_command("System abortTransaction. SystemRepository fullBackupCompressedTo: '#{extend_backup_filename}'")

    log_sh "tar zcf #{backup_filename} #{extend_backup_filename} #{data_directory}/tranlog/tranlog#{tranlog_number}.dbf"
  end

  def restore
    log_sh "tar -C '#{backup_directory}' -zxf '#{backup_filename}'"
    run_topaz_command("SystemRepository restoreFromBackup: '#{extend_backup_filename}'")
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
    directory = "/var/log/gemstone/#{@name}"
    mkdir_p directory
    directory
  end

  def topaz_logfile
    "#{log_directory}/topaz.log"
  end

  def command_logfile
    "#{log_directory}/stone_command_output.log"
  end

  def data_directory
    "/var/local/gemstone/#@name"
  end

  def backup_directory
    "/var/backups/gemstone"
  end

  def backup_filename
    "#{backup_directory}/#{name}_#{Date.today.strftime('%F')}.bak.tgz"
  end

  def extend_backup_filename
    "#{backup_directory}/#{name}_#{Date.today.strftime('%F')}.full.gz"
  end

  def run_topaz_command(command)
    run_topaz_commands(command)
  end

  def run_topaz_commands(commands)
    topaz_commands(["run", commands, "%"].join("\n"))
  end

  def log_sh(command_line)
    sh "echo '#{command_line}' > #{command_logfile}"
    sh "#{command_line} 2>&1 >> #{command_logfile}"
  end

  def initialize_extents
    install(@gemstone_environment.initial_extent, extent_filename, :mode => 0660)
  end

  def topaz_commands(commands)
    script = [
              "output append #{topaz_logfile}",
              "set u #{user_name} p #{password} gemstone #{name}",
              "login",
              "limit oops 100",
              "limit bytes 1000",
              "display oops",
              "iferror stack",
              commands,
              "output pop",
              "exit"
             ].flatten
    Topaz.new(self).commands(script)
  end
end
