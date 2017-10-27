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
        File.open(Systemd.unit_file(domain_name), "w") do |f|
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
            Environment=SECRET_KEY_BASE=${SECRET_KEY_BASE:?"Please set SECRET_KEY_BASE=secret-key-base"}
            Environment=DATABASE_USERNAME=${DATABASE_USERNAME:?"Please set DATABASE_USERNAME=username"}
            Environment=DATABASE_PASSWORD=${DATABASE_PASSWORD:?"Please set DATABASE_PASSWORD=password"}
            Environment=EMAIL_PASSWORD=${EMAIL_PASSWORD:?"Please set EMAIL_PASSWORD=password"}
            Environment=REDIS_URL=unix:///tmp/#{redis_location(domain_name)}.sock

            # The command to start Puma
            # NOTE: TLS would be handled by Nginx
            ExecStart=#{Nginx.root_directory(domain_name)}/bin/puma -b #{puma_uri(domain_name)} \
              --redirect-stdout=#{Nginx.root_directory(domain_name)}//log/puma-production.stdout.log \
              --redirect-stderr=#{Nginx.root_directory(domain_name)}//log/puma-production.stderr.log
            # ExecStart=/usr/local/bin/puma -b tcp://#{puma_uri(domain_name)}

            Restart=always

            [Install]
            WantedBy=multi-user.target
          UNIT_FILE
        end
      end
    end
  end
end
