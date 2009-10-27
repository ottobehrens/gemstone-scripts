require File.join(File.dirname(__FILE__), 'stone')

class GlassStone < Stone

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
