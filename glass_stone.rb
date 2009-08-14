require File.join(File.dirname(__FILE__), 'stone')

class GlassStone < Stone

  def seaside_bin_directory
    "#{gemstone_installation_directory}/seaside/bin"
  end
end
