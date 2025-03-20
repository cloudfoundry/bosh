module CertificateHelpers
  class KeyCache
    @key = nil
    class << self
      attr_accessor :key
    end
  end

  def generate_rsa_certificate(sans: [])
    rsa_private_key = KeyCache.key
    if !rsa_private_key
      rsa_private_key = OpenSSL::PKey::RSA.generate(512) #Smallest key OpenSSL will currently allow to not waste time on cpu cycles
      KeyCache.key = rsa_private_key
    end
    rsa_cert = generate_cert(rsa_private_key, sans: sans)
    private_key_cipher = OpenSSL::Cipher.new 'aes-256-cbc'
    {
      :cert_pem => rsa_cert.to_pem,
      :public_key_pem => rsa_private_key.public_to_pem,
      :private_key_pem => rsa_private_key.to_pem,
    }
  end

  def generate_cert(key, sans: [])
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
    cert.serial = 1 # Not secure, but this is a test certificate
    cert.subject = OpenSSL::X509::Name.parse "/CN=Test CA"
    cert.issuer = cert.subject # root CA's are "self-signed"
    cert.public_key = key
    cert.not_before = 5.minutes.ago
    cert.not_after = cert.not_before + (2 * 7 * 24 * 60 * 60) # 2 weeks validity
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert
    cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
    cert.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
    cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
    cert.add_extension(ef.create_extension('subjectAltName', sans.join(','))) unless sans.empty?
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    cert
  end
end
