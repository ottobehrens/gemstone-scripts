#!/usr/bin/ruby

class GemStoneInstallation
  attr_reader :installation_directory, :config_directory, :installation_extent_directory, :base_log_directory, :backup_directory, :initial_extent_name

  @@current = nil

  # The current, latest and greatest version
  def self.current
    @@current ||= self.new('/opt/gemstone/product')
  end

  def self.current=(instance)
    @@current = instance
  end

  def initialize(installation_directory,
                 config_directory='/opt/gemstone/etc/conf.d',
                 installation_extent_directory='/opt/gemstone/product/data',
                 base_log_directory='/opt/gemstone/log',
                 backup_directory='/opt/gemstone/backups',
                 initial_extent_name='extent0.dbf',
                 seaside_extent_name='extent0.seaside.dbf')

    @installation_directory = installation_directory
    @config_directory = config_directory
    @base_log_directory = base_log_directory
    @installation_extent_directory = installation_extent_directory
    @backup_directory = backup_directory
    @initial_extent_name = initial_extent_name
    @seaside_extent_name = seaside_extent_name
  end

  def set_gemstone_installation_environment
    ENV['GEMSTONE'] = @installation_directory
  end

  def stones
    Dir.glob("#{config_directory}/*").collect do | full_filename |
      File.basename(full_filename).split('.conf').first
    end
  end

  # Execute command in this installation's environment
  def gs_sh(command)
    set_gemstone_installation_environment
    system("$GEMSTONE/bin/#{command}")
    # output = `$GEMSTONE/bin/#{command} 2>&1`
    # if not output.empty? then puts output end
    # $? == 0
  end

  def gslist
    gs_sh 'gslist -clv'
  end

  def stopnetldi
    gs_sh 'stopnetldi | grep Info].*[Ss]erver'
  end

  def startnetldi
    unless netldi_running?
      gs_sh "startnetldi -g -a #{ENV['USER']} | grep Info].*server"
    end
  end

  def netldi_running?
    gs_sh "gslist | grep -qe '^exists.*Netldi'" do | ok, status |
      return status == 0
    end
  end

  def bin_directory
    File.join(@installation_directory, 'bin')
  end

  def upgrade_directory
    File.join(@installation_directory, 'upgrade')
  end

  def initial_extent
    File.join(bin_directory, @initial_extent_name)
  end

  def seaside_extent
    File.join(bin_directory, @seaside_extent_name)
  end
end
