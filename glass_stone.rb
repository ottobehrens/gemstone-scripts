#!/usr/bin/ruby

require 'rake'
require File.join(File.dirname(__FILE__), 'stone')
require 'fileutils'
require 'net/http'

class GlassStone < Stone

  def GlassStone.svc(option, a_service_name)
    fail "service directory #{a_service_name} does not exist" unless File.directory?(a_service_name)
    fail "svc -#{option} #{a_service_name} failed" unless system("svc -#{option} #{a_service_name}")
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

    def run_symlink
      File.join(directory, 'run')
    end

    def service_skeleton_template
      File.join(@@gemstone_scripts_directory, 'service_skeleton')
    end

    def create_daemontools_structure
      if File.exists? directory then
        puts "Service directory #{directory} already exists, not going to overwrite it"
      else
        FileUtils.mkdir_p("#{directory}/log")
        system("cd #{service_skeleton_template}; find -path .git -prune -o -print | cpio -p #{directory}")
        fixup_run_symlink
        FileUtils.touch("#{directory}/down")
      end
    end

    def fixup_run_symlink
      if File.exists?(run_symlink) or File.symlink?(run_symlink)
        File.delete(run_symlink)
      end
      system("ln -s #{run_file_name} #{run_symlink}")
    end

    def svc(option)
      GlassStone.svc(option, directory)
    end

    def start
      option = @stone.name == 'development' ? 'o' : 'u'
      puts("starting service #{directory}") 
      svc(option)
    end  

    def start_fg
      error_message = 'Environment variable LANG not set, you are probably running this from a ' +
                      'restricted shell - bailing out'
      raise error_message unless ENV['LANG']
      fixup_run_symlink
      logfile = "#{@stone.log_directory}/#{log_file_base}.log"
      write_start_time_to_log(logfile)
      [STDOUT, STDERR].each do
        |stream|
        stream.reopen(logfile, 'a')
        stream.flush # Ensure any as-yet unflushed output hits the file
      end
      exec(glass_command)
    end

    def write_start_time_to_log(logfile)
      log = File.open(logfile, 'a')
      log.write("Start time: #{Time.new.inspect}\n")
      log.close unless log.closed?
    end

    def log_file_base
      self.class.name.split('::').last
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

    def monitor
    end

    def alive?
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

    def log_file_base
      "#{super}-#{@port}"
    end
    

    def run_file_name
      File.join(@@gemstone_scripts_directory, 'run_hyper_service')
    end

    def glass_command
      "exec #{@@gemstone_scripts_directory}/glass_hyper #{@port} '#{@stone.name}'"
    end

    def monitor
      if running? and not alive?
        puts "Monitor is restarting #{pid_of_process} at #{Time::now}"
        send_dump_stack_signal
        restart
      end
    end

    def send_dump_stack_signal
      Process.kill('USR1', pid_of_process)
    end

    def alive?
      super and process_listening? and responding?
    end

    class NoProcessOnPortException < Exception
    end

    def pid_of_process
      output = `fuser -n tcp #{@port} 2>/dev/null`
      fail NoProcessOnPortException, "no process listening on port #{@port}" if $? != 0
      output.strip.to_i
    end

    def process_listening?
      begin
        pid_of_process
        stat_service
        true
      rescue Exception
        stat_service
        false
      end
    end

    def stat_service
      system("svstat #{directory}")
    end

    def get_proc_stat_contents
      stat_file_name = "/proc/#{pid_of_process}/stat"
      IO::read(stat_file_name)
    end

    def responding?
      alive = (@stone.http_get_ok?("http://localhost:#{@port}") or some_cpu_activity?)
      puts "!!! hyper on port #{@port} is dead" unless alive
      alive
    end

    def remember_proc_stat_contents
      @proc_stat_contents = get_proc_stat_contents
    end

    def some_cpu_activity?
      remember_proc_stat_contents
      begin
        some_activity = false
        tries = 0
        while not some_activity and tries < 5 do
          sleep 1
          tries += 1
          some_activity = proc_stat_contents_changed?
        end
        puts "process on port #{@port} #{some_activity ? '' : 'not '}busy with something big"
        some_activity
      rescue NoProcessOnPortException => e
        puts "cannot determine activity on port #{@port} (#{e.message})"
        false
      end
    end

    def proc_stat_contents_changed?
      @proc_stat_contents != get_proc_stat_contents
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

    def alive?
      system("svstat #{directory}")
    end
  end

  def http_get_ok?(url)
    uri = URI.parse(url)
    req = Net::HTTP::Get.new("/")
    begin
      res = Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
      ok = (res.code == '200' || res.code == '301') 
      unless ok then puts "Response code 200/301 expected from #{url} but got #{res.code}" end
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
    service_ports_nginx.collect { | port | hyper_service(port) }
  end

  def create_daemontools_structure
    all_services.each do | service | 
      service.create_daemontools_structure
    end
  end

  def start_services
    GlassStone.clear_status
    all_services.each { | service | service.start }
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
    if counter >= timeout_in_seconds
      services.each { |service| service.kill }
      sleep 3
    end
  end

  def stop_services
    all_services.each { | service | service.stop }
    wait_for_services_to_stop(all_services)
  end

  def stop_system
    stop_services
    super
  end

  def stop
    fail 'Service process still running; consider stop_services.' if any_service_process_running?(all_services)
    super
  end

  def any_service_process_running?(services)
    services.any? { | service | service.running? }
  end

  def status
    if running?
      super
      all_services.each { | service | service.alive? }
    else
      puts "#{name} not running"
    end
  end

  def monitor_services
    all_services.each do | service |
      service.monitor
    end
  end

  def nginx_config
    Dir['/etc/nginx/sites-enabled/99-*.conf'].collect do | config_file_name |
      File.open(config_file_name) { | file | file.read }
    end
  end

  def service_ports_nginx
    nginx_config.detect(lambda{fail "Could not find ports for #{name} in #{nginx_config}"}) do | config |
      /upstream #{name}.backend \{/ =~ config
    end
    $~.post_match.scan(/server localhost:(\d{4})/).flatten
  end

  def bootstrapped_with_mc?
    result = topaz_commands(["run", "(System myUserProfile objectNamed: #MCPlatformSupport) notNil", "%"])
    if result =~ /^\[.* Boolean\] true/
      true
    else
      false
    end
  end

  alias :run_topaz_commands_raw :run_topaz_commands
  
  def run_topaz_commands(*commands)
    if bootstrapped_with_mc?
      super(commands.unshift("MCPlatformSupport autoCommit: false; autoMigrate: false"))
    else
      run_topaz_commands_raw(commands)
    end
  end

  def seaside_bin_directory
    "#{gemstone_installation_directory}/seaside/bin"
  end
end

