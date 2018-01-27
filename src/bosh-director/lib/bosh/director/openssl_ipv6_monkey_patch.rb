require 'netaddr'

# OpenSSL ruby library only allows comparison of IPv6 addresses
# in their shrunk form when they are inside certificate SANs.
#
# Rules for shrinking are:
# - remove leading zeroes unless the value is zero
# - all letters must be uppercased
#
# See how IPv6 address looks via `openssl x509 -in cert.pem -noout -text`

class OpenSSLIPv6MonkeyPatch
  def bosh_make_ipv6_hostname_openssl_friendly(hostname)
    parsed_ip = NetAddr::CIDR.create(hostname) rescue nil
    if parsed_ip && parsed_ip.version == 6
      return hostname.upcase.gsub(/(^|:)0+([0-9A-Z]+)/, "\\1\\2")
    end
    return hostname
  end
end

module OpenSSL::SSL
  class << self
    alias_method :orig_verify_certificate_identity, :verify_certificate_identity
  end

  def verify_certificate_identity(cert, hostname)
    return true if orig_verify_certificate_identity(cert, hostname)
    hostname = OpenSSLIPv6MonkeyPatch.new.bosh_make_ipv6_hostname_openssl_friendly(hostname)
    return orig_verify_certificate_identity(cert, hostname)
  end
  module_function :verify_certificate_identity
end
