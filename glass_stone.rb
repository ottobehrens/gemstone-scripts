require 'rake'
require File.join(File.dirname(__FILE__), 'stone')

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
    sh "svc -o /service/clear"
  end

  def service_skeleton_template
    File.join(@@gemstone_scripts_directory, 'service_skeleton')
  end

  def hyper_service_file
    File.join(@@gemstone_scripts_directory, 'run_hyper_service')
  end

  def create_daemontools_structure
    services_names.each do |service_name|
      service_directory = "/service/#{service_name}"
      fail "Service directory #{service_directory} exists, please remove it manually, ensuring all services are stopped" if File.exists? service_directory
      mkdir_p "#{service_directory}/log"
      sh "cd #{service_skeleton_template}; find -path .git -prune -o -print | cpio -p #{service_directory}"
      sh "ln -s #{hyper_service_file} #{service_directory}/run"
      touch "#{service_directory}/down"
    end
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
      sh "svc -u /service/#{service_name}" }
  end

  def start_hyper(port)
    if pid=fork
      system("nohup #{glass_hyper_command(port)} &")
      Process.detach(pid)
    end
  end

  def start_hyper_fg(port)
    raise 'Environment variable LANG not set, you are probably running this from a restricted shell - bailing out' if not ENV['LANG'] 
    system(glass_hyper_command(port))
  end

  def glass_hyper_command(port)
    "#{@@gemstone_scripts_directory}/glass_hyper #{port} '#{name}'"
  end

  def start_system
    super
    start_hypers
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

  def stop_hypers
    services_names.each { |service_name| sh "svc -d /service/#{service_name}" }
    sleep 1
    fuser_hyper_ports("-k")
  end

  def status_hypers
    hyper_ports.each do | port |
      status_hyper_port(port)
    end
  end

  def any_hyper_running?
    !(hyper_ports.detect {| port | status_hyper_port(port)}).nil?
  end

  def any_hyper_supposed_to_be_running?
    services_names.detect do |service_name|
      !(`svstat /service/#{service_name}` =~ /service\/#{service_name}: up/).nil?
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
  end

  def lighty_config_template(ports)
    return <<-TEMPLATE
$HTTP["host"] == "#{name}" {
  $HTTP["url"] =~ "^/documents/|^/tfiles/^|/resources/" {
    alias.url += (
      "/documents/" => "/var/local/gemstone/#{name}/public_uploads/",
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

  def status_hyper_port(port)
    sh "svstat /service/#{name}-#{port}"
    fuser_hyper_port(port)
  end

  def fuser_hyper_ports(extra_flags = "")
    hyper_ports.each do |port|
      fuser_hyper_port(port, extra_flags)
    end
  end

  def fuser_hyper_port(port, extra_flags = "")
    sh "fuser #{extra_flags} -n tcp #{port} 2> /dev/null" do |ok, status|
      if ok
        puts " = pid of process running a hyper on port #{port}"
      else
        puts "Could not find a hyper on port #{port}"
      end
      return ok
    end
    return false
  end
end

