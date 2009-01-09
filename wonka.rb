class Wonka
  def self.package_directory 
    File.dirname(File.join([__FILE__, '../monticello']))
  end
end

class WonkaStone < Stone
  def bootstrap
    @topaz_runner.commands("input #{Wonka.package_directory}/Deployer.gs")
  end
end
