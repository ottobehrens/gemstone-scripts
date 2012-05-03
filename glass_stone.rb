require 'rake'
require File.join(File.dirname(__FILE__), 'stone')
require 'net/http'

class GlassStone < Stone

  def GlassStone.svc(option, a_service_name)
    fail "service directory #{a_service_name} does not exist" if not File.directory?(a_service_name)
    fail "svc -#{option} #{a_service_name} failed" if not system("svc -#{option} #{a_service_name}") 
  end

  def GlassStone.clear_status
    svc('o', '/service/clear')
  end

  class Service

    @@gemstone_scripts_directory = File.expand_path(File.dirname(__FILE__))

    def initialize(stone)
      @stone = stone
    end

    def directory
      "/service/#{@stone.name}"
    end

    def service_skeleton_template
      File.join(@@gemstone_scripts_directory, 'service_skeleton')
    end

    def create_daemontools_structure
      if File.exists? directory then
        puts "Service directory #{directory} already exists, not going to overwrite it"
      else
        mkdir_p "#{directory}/log"
        system("cd #{service_skeleton_template}; find -path .git -prune -o -print | cpio -p #{directory}")
        system("ln -s #{run_file_name} #{directory}/run")
        touch "#{directory}/down"
      end
    end

    def svc(option)
      GlassStone.svc(option, directory)
    end

    def start
      option = if @stone.name == 'development' then 'o' else 'u' end
      puts("starting service #{directory}") 
      svc(option)
    end  

    def start_fg
      raise 'Environment variable LANG not set, you are probably running this from a restricted shell - bailing out' if not ENV['LANG'] 
      exec(glass_command)
    end

    def stop
      puts("stopping #{directory}") 
      svc('d')
    end

    def restart
      stop
      sleep 3
      start
    end

    def kill
      puts("killing #{directory}") 
      svc('k')
    end

    def running?
      is_running = `svstat #{directory}` =~ /#{directory}: up/
      fail "failed to determine if #{directory} is running" if $? != 0
      is_running
    end

    def ensure_alive
      if running? and not alive? then
        restart
      end
    end

    def alive?
      system("svstat #{directory}")
      true
    end
  end

  class HyperService < Service
    def initialize(stone, port)
      super(stone)
      @port = port
    end

    def directory
      "#{super}-#{@port}"
    end

    def run_file_name
      File.join(@@gemstone_scripts_directory, 'run_hyper_service')
    end

    def glass_command
      "exec #{@@gemstone_scripts_directory}/glass_hyper #{@port} '#{@stone.name}'"
    end

    def alive?
      super and process_listening? and responding?
    end

    class NoProcessOnPortException < Exception
    end

    def pid_of_process(extra_flags = "")
      pid = `fuser #{extra_flags} -n tcp #{@port} 2>/dev/null`.strip
      fail NoProcessOnPortException, "no process listening on port #{@port}" if $? != 0
      pid
    end

    def process_listening?(extra_flags = "")
      begin
        pid = pid_of_process(extra_flags)
        puts "#{pid} = pid of process listening on port #{@port}"
        true
      rescue Exception
        puts "No process listening on port #{@port}"
        false
      end
    end

    def get_proc_stat_contents
      stat_file_name = "/proc/#{pid_of_process}/stat"
      contents = `cat #{stat_file_name}`
      fail "could not cat #{stat_file_name}" if $? != 0
      contents
    end

    def remember_proc_stat_contents
      @proc_stat_contents = get_proc_stat_contents
    end

    def responding?
      remember_proc_stat_contents
      alive = @stone.http_get_ok?("http://localhost:#{@port}") or some_cpu_activity?
      if not alive then puts "!!! hyper on port #{@port} is dead" end
      alive
    end

    def some_cpu_activity?
      begin
        tries = 1
        no_activity = proc_stat_contents_the_same?
        while no_activity and tries < 5 do
          sleep 1
          tries = tries + 1
          no_activity = proc_stat_contents_the_same?
        end
        puts "process on port #{@port} #{if no_activity then 'not ' else '' end}busy with something big"
        not no_activity
      rescue NoProcessOnPortException => e
        puts "cannot determine activity on port #{@port} (#{e.message})"
        false
      end
    end

    def proc_stat_contents_the_same?
      @proc_stat_contents == get_proc_stat_contents
    end
  end

  class MaintenanceService < Service
    def directory
      "#{super}-maintenance"
    end

    def run_file_name
      File.join(@@gemstone_scripts_directory, 'run_maintenance_service')
    end

    def glass_command
      "exec #{@@gemstone_scripts_directory}/glass_maintenance '#{@stone.name}'"
    end
  end

  def http_get_ok?(url)
    uri = URI.parse(url)
    req = Net::HTTP::Get.new("/")
    begin
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      ok = res.code == '200'
      if not ok then puts "Response code 200 expected from #{url} but got #{res.code}" end
      ok
    rescue Exception => e
      puts "get #{url} failed with #{e.message}"
      false
    end
  end

  def all_services
    [maintenance_service] + hyper_services
  end

  def maintenance_service
    MaintenanceService.new(self)
  end

  def hyper_service(port)
    HyperService.new(self, port)
  end

  def hyper_services
    hyper_ports_lighty.collect { | port | hyper_service(port) }
  end

  def create_daemontools_structure
    all_services.each do | service | 
      service.create_daemontools_structure
    end
  end

  def start_services(services=nil)
    GlassStone.clear_status
    (services || all_services).each { | service | service.start }
  end

  def start_hypers
    start_services(hyper_services)
  end

  def kill_services(services)
    services.each { |service| service.kill }
  end

  def start_maintenance
    maintenance_service.start
  end

  def stop_maintenance
    maintenance_service.stop
  end

  def start_system
    super
    start_services
  end

  def wait_for_services_to_stop(services, timeout_in_seconds = 20)
    counter = 0
    while any_service_process_running?(services) and (counter < timeout_in_seconds) do
      sleep 1
      counter = counter + 1
    end
    if counter >= timeout_in_seconds then
      kill_services(services)
    end
  end

  def stop_services(services=nil)
    (services || all_services).each { | service | service.stop }
    wait_for_services_to_stop(services || all_services)
  end

  def stop_system
    stop_services
    super
  end

  def stop
    fail "Service process still running; consider stop_services." if any_service_process_running?
    super
  end

  def stop_hypers
    stop_services(hyper_services)
  end

  def any_service_process_running?(services=nil)
    (services || all_services).any? { | service | service.running? }
  end

  def lighty_config
    Dir["/etc/lighttpd/conf-available/99-*.conf"].collect do | config_file_name |
      File.open(config_file_name) { | file | file.read }
    end
  end

  def status
    if running?
      super
      all_services.each { | service | service.alive? }
    else
      puts "#{name} not running"
    end
  end

  def hyper_ports_lighty
    lighty_config.detect(lambda{fail "Could not find ports for #{name} in #{lighty_config}"}) do | config |
      /HTTP\["host"\]\s+==\s+"#{name}"\s+\{/ =~ config
    end
    $~.post_match.scan(/"port" => (\d{4})/).flatten
  end

  def ensure_hypers_are_alive
    hyper_services.each do | service |
      service.ensure_alive
    end
  end

  def bootstrapped_with_mc?
    result = topaz_commands(["run", "(System myUserProfile objectNamed: #MCPlatformSupport) notNil", "%"])
    if result.last =~ /^\[.* Boolean\] true/
      true
    else
      false
    end
  end
  
  def run_topaz_commands(*commands)
    if bootstrapped_with_mc?
      super(commands.unshift("MCPlatformSupport autoCommit: false; autoMigrate: false"))
    else
      super(commands)
    end
  end
  
  def seaside_bin_directory
    "#{gemstone_installation_directory}/seaside/bin"
  end
end

