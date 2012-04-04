require 'rake'
require File.join(File.dirname(__FILE__), 'stone')
require 'net/http'

class GlassStone < Stone

  @@gemstone_scripts_directory = File.expand_path(File.dirname(__FILE__))

  def GlassStone.svc(option, a_service_name)
    fail "service directory #{a_service_name} does not exist" if not File.directory?(a_service_name)
    fail "svc -#{option} #{a_service_name} failed" if not system("svc -#{option} #{a_service_name}") 
  end

  def GlassStone.clear_status
    svc('o', '/service/clear')
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

  def service_skeleton_template
    File.join(@@gemstone_scripts_directory, 'service_skeleton')
  end

  def hyper_service_file
    File.join(@@gemstone_scripts_directory, 'run_hyper_service')
  end

  def maintenance_service_file
    File.join(@@gemstone_scripts_directory, 'run_maintenance_service')
  end

  def maintenance_service
    "/service/#{name}-maintenance"
  end  

  def create_daemontools_structure
    create_maintenance_daemontools_structure
    services_names.each do |a_service_name|
      create_daemontools_structure_for(a_service_name, hyper_service_file)
    end
  end

  def create_daemontools_structure_for(a_service_name, run_file)
      fail "Service directory #{a_service_name} exists, please remove it manually, ensuring all services are stopped" if File.exists? a_service_name
      mkdir_p "#{a_service_name}/log"
      system("cd #{service_skeleton_template}; find -path .git -prune -o -print | cpio -p #{a_service_name}")
      system("ln -s #{run_file} #{a_service_name}/run")
      touch "#{a_service_name}/down"
  end

  def create_maintenance_daemontools_structure
    create_daemontools_structure_for(maintenance_service, maintenance_service_file)
  end

  def remove_daemontools_structure
    services_names.each do |a_service_name|
      rm_rf a_service_name if File.exists? a_service_name
    end
  end

  def start_hyper(port)
    start_service_named(service_name(port))
  end

  def start_hypers
    GlassStone.clear_status
    hyper_ports.each { |port| start_hyper(port) }
  end

  def start_maintenance
    start_service_named(maintenance_service) 
  end

  def start_service_named(a_service_name)
    option = if name == 'development' then 'o' else 'u' end
    puts("starting service #{a_service_name}") 
    GlassStone.svc(option, a_service_name)
  end  

  def start_maintenance_fg
    raise 'Environment variable LANG not set, you are probably running this from a restricted shell - bailing out' if not ENV['LANG'] 
    exec(glass_maintenance_command)
  end

  def glass_maintenance_command
    "exec #{@@gemstone_scripts_directory}/glass_maintenance '#{name}'"
  end

  def start_hyper_fg(port)
    raise 'Environment variable LANG not set, you are probably running this from a restricted shell - bailing out' if not ENV['LANG'] 
    exec(glass_hyper_command(port))
  end

  def glass_hyper_command(port)
    "exec #{@@gemstone_scripts_directory}/glass_hyper #{port} '#{name}'"
  end

  def start_services
    start_hypers
    start_maintenance
  end

  def start_system
    super
    start_services
  end

  def wait_for_hypers_to_stop(timeout_in_seconds = 20)
    counter = 0
    while any_service_process_running? and (counter < timeout_in_seconds) do
      sleep 1
      counter = counter + 1
    end
    fail "Waiting for hypers to stop timeout (#{counter})" if counter == timeout_in_seconds
  end

  def status_hypers
    hyper_ports.each do | port |
      hyper_alive?(port)
    end
  end

  def stop_services
    stop_maintenance
    stop_hypers
  end

  def stop_system
    stop_services
    super
  end

  def stop
    fail "Hyper process still running; consider stop_services." if any_service_process_running?
    super
  end

  def stop_maintenance
    GlassStone.svc('d', maintenance_service) 
  end

  def stop_hyper(port)
    puts("stopping hyper #{service_name(port)}") 
    GlassStone.svc('d', service_name(port))
  end

  def stop_hypers
    hyper_ports.each { |port| stop_hyper(port) }
    wait_for_hypers_to_stop
  end

  def hyper_process_is_running?(port)
    service_process_is_running?(service_name(port))
  end

  def service_process_is_running?(a_service_name)
    is_running = `svstat #{a_service_name}` =~ /#{a_service_name}: up/
    fail "failed to determine if #{a_service_name} is running" if $? != 0
    is_running
  end

  def any_service_process_running?
    hyper_ports.detect { |port| hyper_process_is_running?(port) } or service_process_is_running?(maintenance_service)
  end

  def hyper_ports
    hyper_ports_lighty
  end

  def lighty_config
    Dir["/etc/lighttpd/conf-available/99-*.conf"].collect do | config_file_name |
      File.open(config_file_name) { | file | file.read }
    end
  end

  def status
    super
    status_hypers
    status_maintenance
  end

  def lighty_config_template(ports)
    return <<-TEMPLATE
$HTTP["host"] == "#{name}" {
  $HTTP["url"] =~ "^/documents/|^/tfiles/^|/resources/" {
    alias.url += (
      "/documents/" => "/var/local/gemstone/#{name}/documents/",
      "/tfiles/" => "/tmp/#{name}/",
      "/resources/" => "/home/wonka/projects/wonka/resources/"
    )
  } else $HTTP["url"] =~ ".*" {
    proxy.server  = ( "" => ( 
#{generate_ports(ports)}
                          ) )
  }
}
    TEMPLATE
  end

  def create_lighty_config(ports)
    File.open("/etc/lighttpd/conf-available/99-#{name}.conf", "w+") do | file |
      file.print(lighty_config_template(ports))
    end
  end

  def remove_lighty_config
    config = "/etc/lighttpd/conf-available/99-#{name}.conf"
    File.delete(config) if File.exists? config
  end

  def generate_ports(ports)
    ports.collect { | port | "\t\t\t( \"host\" => \"127.0.0.1\", \"port\" => #{port} ),\n" }
  end

  def hyper_ports_lighty
    lighty_config.detect(lambda{fail "Could not find ports for #{name} in #{lighty_config}"}) do | config |
      /HTTP\["host"\]\s+==\s+"#{name}"\s+\{/ =~ config
    end
    $~.post_match.scan(/"port" => (\d{4})/).flatten
  end

  def services_names
    hyper_ports_lighty.collect { | port | service_name(port) }
  end

  def service_name(port)
    "/service/#{name}-#{port}"
  end

  def status_maintenance
    system("svstat #{maintenance_service}")
  end

  def restart_hyper(port)
    stop_hyper(port)
    sleep 3
    start_hyper(port)
  end

  def ensure_hypers_are_alive
    hyper_ports.each do | port |
      if hyper_process_is_running?(port) and not hyper_alive?(port) then
        restart_hyper(port)
      end
    end
  end

  def hyper_alive?(port)
    system("svstat /service/#{name}-#{port}")
    process_listening?(port) and hyper_responding?(port)
  end

  class NoProcessOnPortException < Exception
  end

  def pid_of_process(port, extra_flags = "")
    pid = `fuser #{extra_flags} -n tcp #{port} 2>/dev/null`.strip
    fail NoProcessOnPortException, "no process listening on port #{port}" if $? != 0
    pid
  end

  def process_listening?(port, extra_flags = "")
    begin
      pid = pid_of_process(port, extra_flags)
      puts "#{pid} = pid of process listening on port #{port}"
      true
    rescue Exception
      puts "No process listening on port #{port}"
      false
    end
  end

  def get_proc_stat_contents(port)
    stat_file_name = "/proc/#{pid_of_process(port)}/stat"
    contents = `cat #{stat_file_name}`
    fail "could not cat #{stat_file_name}" if $? != 0
    contents
  end

  def remember_proc_stat_contents(port)
    @proc_stat_contents = get_proc_stat_contents(port)
  end

  def hyper_responding?(port)
    remember_proc_stat_contents(port)
    alive = http_get_ok?("http://localhost:#{port}") or some_cpu_activity?(port)
    if not alive then puts "!!! hyper on port #{port} is dead" end
    alive
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
    
  def some_cpu_activity?(port)
    begin
      tries = 1
      no_activity = proc_stat_contents_the_same?(port)
      while no_activity and tries < 5 do
        sleep 1
        tries = tries + 1
        no_activity = proc_stat_contents_the_same?(port)
      end
      puts "process on port #{port} #{if no_activity then 'not ' else '' end}busy with something big"
      not no_activity
    rescue NoProcessOnPortException => e
      puts "cannot determine activity on port #{port} (#{e.message})"
      false
    end
  end

  def proc_stat_contents_the_same?(port)
    @proc_stat_contents == get_proc_stat_contents(port)
  end
end

