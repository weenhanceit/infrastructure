##
# Act like the Config class, but put files in /tmp. Also provides a method
# to find the fake root.
class ConfigMock < Config
  include FileUtils

  PATH_METHODS = %i[
    certificate_directory
    root_directory
    server_block_location
  ].freeze

  PATH_METHODS.each do |method|
    define_method method do
      File.join fake_root, super()
    end
  end

  def fake_root
    ConfigMock.fake_root
  end

  def initialize(domain_name, user: "ubuntu", proxy_url: nil)
    super
    FileUtils.mkdir_p(certificate_directory)
    FileUtils.mkdir_p(root_directory)
    FileUtils.mkdir_p(File.dirname(server_block_location))
    FileUtils.mkdir_p(File.join(fake_root, "/etc/nginx/sites-available"))
    FileUtils.mkdir_p(File.join(fake_root, "/etc/nginx/sites-enabled"))
  end

  class << self
    def fake_root
      "/tmp/builder_test"
    end
  end
end
