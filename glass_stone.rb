require File.join(File.dirname(__FILE__), 'stone')

class GlassStone < Stone

  def run_topaz_commands(*commands)
    theCommands = begin
      topaz_commands(["run", "MCPlatformSupport", "%"])
      commands.unshift("MCPlatformSupport autoCommit: false; autoMigrate: false")
    rescue TopazError
      commands
    end
    super(theCommands)
  end
  
  def seaside_bin_directory
    "#{gemstone_installation_directory}/seaside/bin"
  end
end
