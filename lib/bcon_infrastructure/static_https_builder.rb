class StaticHttpsBuilder < StaticHttpBuilder
  def build
    super
    `openssl dhparam 2048 -out #{@config.certificate_directory}/dhparam.pem`
  end
end
