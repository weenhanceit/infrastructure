# frozen_string_literal: true

module Systemd
  module Rails
    class << self
      def puma_uri(domain_name)
        "unix:///tmp/#{domain_name}.sock"
      end

      def redis_location(domain_name)
        "redis." + domain_name
      end

      def write_unit_file(domain_name)
        if ENV["SECRET_KEY_BASE"].nil? ||
           ENV["DATABASE_USERNAME"].nil? ||
           ENV["DATABASE_PASSWORD"].nil? ||
           ENV["EMAIL_PASSWORD"].nil?
          raise "Missing environment variable"
        end

        puts "writing unit file (domain_name): #{Systemd.unit_file(domain_name)} (#{domain_name})" if Runner.debug

        result = File.open(Systemd.unit_file(domain_name), "w") do |f|
          f << <<~UNIT_FILE
            [Unit]
            Description=Puma HTTP Server for #{domain_name}
            After=network.target

            # Uncomment for socket activation (see below)
            # Requires=#{domain_name}.socket

            [Service]
            # Foreground process (do not use --daemon in ExecStart or config.rb)
            Type=simple

            User=nobody
            Group=www-data

            # Specify the path to the Rails application root
            WorkingDirectory=#{Nginx.root_directory(domain_name)}

            # Helpful for debugging socket activation, etc.
            # Environment=PUMA_DEBUG=1
            Environment=RACK_ENV=production
            Environment=RAILS_ENV=production
            Environment=SECRET_KEY_BASE=#{ENV['SECRET_KEY_BASE']}
            Environment=DATABASE_USERNAME=#{ENV['DATABASE_USERNAME']}
            Environment=DATABASE_PASSWORD=#{ENV['DATABASE_PASSWORD']}
            Environment=EMAIL_PASSWORD=#{ENV['EMAIL_PASSWORD']}
            Environment=REDIS_URL=unix:///tmp/#{redis_location(domain_name)}.sock

            # The command to start Puma
            # NOTE: TLS would be handled by Nginx
            ExecStart=#{Nginx.root_directory(domain_name)}/bin/puma -b #{puma_uri(domain_name)} \
              --redirect-stdout=#{Nginx.root_directory(domain_name)}/log/puma-production.stdout.log \
              --redirect-stderr=#{Nginx.root_directory(domain_name)}/log/puma-production.stderr.log
            # ExecStart=/usr/local/bin/puma -b tcp://#{puma_uri(domain_name)}

            Restart=always

            [Install]
            WantedBy=multi-user.target
          UNIT_FILE
        end

        puts "changing mode of unit file" if Runner.debug
        FileUtils.chmod(0o600, Systemd.unit_file(domain_name))
        puts "enabling service" if Runner.debug && Process.uid.zero?
        `sudo systemctl enable $domain_name.service` if Process.uid.zero?

        result
      end
    end
  end
end
