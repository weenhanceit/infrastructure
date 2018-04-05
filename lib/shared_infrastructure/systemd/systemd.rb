module Systemd
  class Configuration
    def initialize
      @unit_file_path = "#{Nginx.root}/lib/systemd/system"
    end

    def unit_file(domain_name)
      File.join(unit_file_path, domain_name + ".service")
    end

    attr_accessor :unit_file_path
  end

  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    %i[
      unit_file
    ].each do |method|
      define_method method do |domain_name|
        configuration.send(method, domain_name)
      end
    end
  end
end
