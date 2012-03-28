require 'rake'
require File.join(File.dirname(__FILE__), 'stone')
require 'net/http'

class GlassStone < Stone

  @@gemstone_scripts_directory = File.expand_path(File.dirname(__FILE__))

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

  def GlassStone.clear_status
    system("svc -o /service/clear")
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
    "#{name}-maintenance"
  end  
  def create_daemontools_structure
    create_maintenance_daemontools_structure
    services_names.each do |service_name|
      create_daemontools_structure_for(service_name, hyper_service_file)
    end
  end

  def create_daemontools_structure_for(service_name, run_file)
      service_directory = "/service/#{service_name}"
      fail "Service directory #{service_directory} exists, please remove it manually, ensuring all services are stopped" if File.exists? service_directory
      mkdir_p "#{service_directory}/log"
      system("cd #{service_skeleton_template}; find -path .git -prune -o -print | cpio -p #{service_directory}")
      system("ln -s #{run_file} #{service_directory}/run")
      touch "#{service_directory}/down"
  end

  def create_maintenance_daemontools_structure
    create_daemontools_structure_for(maintenance_service, maintenance_service_file)
  end

  def remove_daemontools_structure
    services_names.each do |service_name|
      service_directory = "/service/#{service_name}"
      rm_rf service_directory if File.exists? service_directory
    end
  end

  def start_hypers
    GlassStone.clear_status
    services_names.each { |service_name| 
      start_service_named(service_name) }
  end

  def start_maintenance
    start_service_named(maintenance_service) 
  end

  def start_service_named(a_service_name)
      option = if name == 'development' then 'o' else 'u' end
      puts("Starting service #{a_service_name}") 
      system("svc -#{option} /service/#{a_service_name}") 
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

  def start_system
    super
    start_hypers
    start_maintenance
  end

  def wait_for_hypers_to_stop(timeout_in_seconds = 20)
    counter = 0
    while any_hyper_running? and counter < timeout_in_seconds
      sleep 1
      counter = counter + 1
    end
  end

  def stop_system
    stop_hypers
    super
  end

  def stop
    fail "Daemontools still attempting to start hypers, consider stop_hypers." if any_hyper_supposed_to_be_running?
    fail "Some hypers still running. Consider stopping them first." if any_hyper_running?
    super
  end

  def stop_maintenance
    system("svc -d /service/#{maintenance_service}") 
  end

  def stop_hypers
    services_names.each { |service_name| system("svc -d /service/#{service_name}") }
    wait_for_hypers_to_stop
  end

  def status_hypers
    hyper_ports.each do | port |
      status_hyper_port(port)
    end
  end

  def any_hyper_running?
    !(hyper_ports.detect {| port | process_listening?(port)}).nil?
  end

  def any_hyper_supposed_to_be_running?
    services_names.detect do |service_name|
      !(`svstat /service/#{service_name}` =~ /service\/#{service_name}: up/).nil? and \
      !File.exists?("/service/#{service_name}/down")
    end
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
    hyper_ports_lighty.collect { | port | "#{name}-#{port}" }
  end

  def status_maintenance
    system("svstat /service/#{maintenance_service}")
  end

  def status_hyper_port(port)
    system("svstat /service/#{name}-#{port}")
    process_listening?(port) and hyper_port_alive?(port)
  end

  def pid_of_process(port, extra_flags = "")
    pid = `fuser #{extra_flags} -n tcp #{port} 2>/dev/null`.strip
    fail "no process listening on port #{port}" if $? != 0
    pid
  end

  def process_listening?(port, extra_flags = "")
    begin
      pid = pid_of_process(port, extra_flags)
      puts "#{pid} = pid of process listening on port #{port}"
      true
    rescue
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

  def hyper_port_alive?(port)
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
    tries = 1
    activity = change_in_proc_stat_contents(port)
    while not activity and tries < 3 do
      tries = tries + 1
      activity = change_in_proc_stat_contents(port)
    end
    puts "hyper on port #{port} #{if activity then '' else 'not ' end}busy with something big"
  end
end

