module Bosh::Director
  class NatsClientCertGenerator

    def initialize(logger)
      @logger = logger

      if Config.nats_client_ca_private_key_path.nil?
        raise DeploymentGeneratorCAInvalid, 'Client certificate generation error. Config for nats_client_ca_private_key_path is nil.'
      end

      if Config.nats_client_ca_certificate_path.nil?
        raise DeploymentGeneratorCAInvalid, 'Client certificate generation error. Config for nats_client_ca_certificate_path is nil.'
      end

      if !File.exists?(Config.nats_client_ca_private_key_path)
        raise DeploymentGeneratorCAInvalid, 'Client certificate generation error. Config for nats_client_ca_private_key_path is not found.'
      end

      if !File.exists?(Config.nats_client_ca_certificate_path)
        raise DeploymentGeneratorCAInvalid, 'Client certificate generation error. Config for nats_client_ca_certificate_path is not found.'
      end

      @root_ca = load_cert(Config.nats_client_ca_certificate_path)
      @root_key = load_key(Config.nats_client_ca_private_key_path)

      if !verify(@root_ca, @root_key)
        raise DeploymentGeneratorCAInvalid, 'Configured nats_client_ca_certificate_path points to an invalid certificate.'
      end
    end

    def generate_nats_client_certificate(common_name)
      key = OpenSSL::PKey::RSA.new 3072
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2

      cert.serial = SecureRandom.hex(16).to_i(16)

      cert.subject = OpenSSL::X509::Name.parse "/C=USA/O=Cloud Foundry/CN=#{common_name}"
      cert.issuer = @root_ca.subject # root CA is the issuer
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = cert.not_before + 2 * 365 * 24 * 60 * 60 # 2 years validity
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = @root_ca
      cert.add_extension(ef.create_extension('keyUsage', 'digitalSignature', true))
      cert.add_extension(ef.create_extension('basicConstraints', 'CA:false', true))
      cert.add_extension(ef.create_extension('extendedKeyUsage', 'clientAuth', true))
      cert.sign(@root_key, OpenSSL::Digest::SHA256.new)

      {:cert => cert, :key => key, :ca_key => @root_key.public_key}
    end

    private

    def load_cert(path)
      OpenSSL::X509::Certificate.new(File.read(path))
    end

    def load_key(path)
      raw_cert = File.read(path)
      OpenSSL::PKey::RSA.new raw_cert
    end

    def verify(cert, key)
      cert.verify(key)
    end
  end
end
