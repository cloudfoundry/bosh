require 'spec_helper'
require 'bosh/director/openssl_ipv6_monkey_patch'

describe "openssl ipv6 monkey patch" do
  # Below certificates were generated with the following config
  # via `bosh int certs.yml --vars-store creds.yml`
  certs_config = <<-CERTS
variables:
- name: leaf-with-name
  type: certificate
  options:
    is_ca: true
    common_name: cn-in-cert
- name: leaf-with-ip
  type: certificate
  options:
    is_ca: true
    common_name: 1.2.3.4
- name: leaf-with-ipv6
  type: certificate
  options:
    is_ca: true
    common_name: 2001:4860:4860:0000:0000:0000:0000:8888

- name: leaf-with-ipv6-in-alt-name-ca
  type: certificate
  options:
    is_ca: true
    common_name: ca
- name: leaf-with-ipv6-in-alt-name
  type: certificate
  options:
    ca: leaf-with-ipv6-in-alt-name-ca
    common_name: cn-in-cert
    alternative_names:
    - 2001:4860:4860:0000:0000:0000:0000:0088
CERTS

  it 'properly shrinks IPv6 addresses' do
    cases = {
      # shrink middle 0s
      "2001:4860:4860:0000:0000:0000:0000:8888" => "2001:4860:4860:0:0:0:0:8888",
      "2001:4860:4860:0000:0001:0000:0000:8888" => "2001:4860:4860:0:1:0:0:8888",
      "2001:4860:4860:0000:0011:0000:0000:8888" => "2001:4860:4860:0:11:0:0:8888",
      "2001:4860:4860:0000:0111:0000:0000:8888" => "2001:4860:4860:0:111:0:0:8888",
      "2222:4860:4860:1111:1111:1000:1111:8888" => "2222:4860:4860:1111:1111:1000:1111:8888", # middle trailing 0s

      # starting with 0s
      "0000:4860:4860:1111:1111:1111:1111:1188" => "0:4860:4860:1111:1111:1111:1111:1188",
      "0001:4860:4860:1111:1111:1111:1111:1188" => "1:4860:4860:1111:1111:1111:1111:1188",
      "0011:4860:4860:1111:1111:1111:1111:1188" => "11:4860:4860:1111:1111:1111:1111:1188",
      "0111:4860:4860:1111:1111:1111:1111:1188" => "111:4860:4860:1111:1111:1111:1111:1188",

      # finishing with 0s
      "2222:4860:4860:1111:1111:1111:1111:0000" => "2222:4860:4860:1111:1111:1111:1111:0",
      "2222:4860:4860:1111:1111:1111:1111:0008" => "2222:4860:4860:1111:1111:1111:1111:8",
      "2222:4860:4860:1111:1111:1111:1111:0088" => "2222:4860:4860:1111:1111:1111:1111:88",
      "2222:4860:4860:1111:1111:1111:1111:0888" => "2222:4860:4860:1111:1111:1111:1111:888",

      "00aa:00bb:00cc:0dd:ee:ff:1111:8888" => "AA:BB:CC:DD:EE:FF:1111:8888", # uppercased
    }
    cases.each { |from,to|
      expect(OpenSSLIPv6MonkeyPatch.new.bosh_make_ipv6_hostname_openssl_friendly(from)).to(eq(to))
    }
  end

  it 'should not shrink non-valid IPv6 addresses' do
    cases = {
      ":0000" => ":0000",
      "127.0.0.1" => "127.0.0.1",
      "127.00.00.1" => "127.00.00.1",
      "localhost.0000.nono.io" => "localhost.0000.nono.io",
      "nono0000.io" => "nono0000.io",
      "0000.io" => "0000.io",
    }
    cases.each { |from,to|
      expect(OpenSSLIPv6MonkeyPatch.new.bosh_make_ipv6_hostname_openssl_friendly(from)).to(eq(to))
    }
  end

  it 'continues to fail for invalid certificates (standard behaviour)' do
    cert_with_name_in_cn_pem = <<-CERT
-----BEGIN CERTIFICATE-----
MIIDJDCCAgygAwIBAgIRAJ0+abKTri5tb2oBJzM19xowDQYJKoZIhvcNAQELBQAw
OzEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MRMwEQYDVQQD
Ewpjbi1pbi1jZXJ0MB4XDTE4MDEyNzAxMjgxMVoXDTE5MDEyNzAxMjgxMVowOzEM
MAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MRMwEQYDVQQDEwpj
bi1pbi1jZXJ0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAumieJgeN
GFg+aw/04sR14JMCksrHQZx4vRpkeDuxsZpL4jiOow/nxwvi3g1vxpWKd1gYhWvW
qSDs/grrWsW7HpHi1BjJfjDgKc3DU09sTgAJ0oyUuGWkCcrbSpiTeDEvpLDczSl6
70+jPpDqY68H4ii/sQ3dMODCuUUnShrxIUBf7AT+OfUASGK1eZ5gVc18te+zkYc7
jk59D3Iwai+RZjpFcIOTv8bgPetnlcsYyj9g0gFfVT/frlcJgv3vZnjKosOFsR54
oZ1lKPsG4vtC7Lp0vDTWTr+CU8D/efj0YMdbOXda1XjNWx6aw/sZ3PioKVVXD7h1
6Wy+upbAd41yswIDAQABoyMwITAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUw
AwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAAhoBucqNUC/D3xQd9zj3sqN4azfF/Ygt
llQXpI1D+IRFwWll26tk0MyOlRXPIBYTEUCumGrIdGVJXX3zGei2sgxpmVLzO5a+
txXUrZ0TWSMMJM62CDUMtFuhT3bUDOvCLe1r+eVQ9BOweUBUC4iZUDOpFxcA2BMt
Lo+dz9XR+dBaw0oma6l47NnGNjtAXYLQcYQTsQghkftBZjRj+CSqYltoL6bBYbeN
ZAhDHl1ueISGLCCmFjZ/ploQHYqsfNi3umAExjmXOWW5fGew0aFyApIoLW3cglvX
tOIoRy8MRZ4OjR/TQaXcHfZJ5gdt+1lzUoTiS8sQXmmKP3DXLcZ/og==
-----END CERTIFICATE-----
CERT

    cert = OpenSSL::X509::Certificate.new(cert_with_name_in_cn_pem)
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "cn-not-in-cert")).to(eq(false))
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "cn-in-cert")).to(eq(true))
  end

  it 'continues to fail for invalid certificates with CN that has IPv4' do
    cert_with_ip_in_cn_pem = <<-CERT
-----BEGIN CERTIFICATE-----
MIIDHTCCAgWgAwIBAgIQUaTLxaenAHTF4r3WTSZV2jANBgkqhkiG9w0BAQsFADA4
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkxEDAOBgNVBAMT
BzEuMi4zLjQwHhcNMTgwMTI3MDEzMTMyWhcNMTkwMTI3MDEzMTMyWjA4MQwwCgYD
VQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkxEDAOBgNVBAMTBzEuMi4z
LjQwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDCkCBIXwFk7uX1Hpwg
1aw91ATcDQZGqCnR0B64SMQX51+Hrdgt7B0MKxxkHS0qM68z62mUSV1np/AXdJmn
bM1nHXSWIRmwowUFTuC8JE40rQHL3sQgLWD9oyLhJxqdXraroFehAhfGKIjhtiuL
Z00/vBXMpopeMriIU5YTsYtVXRcgn4Yq9eWzi1ym705qEKgfIyQTHc+BRvrzyjzV
x/bOGFDiRRHDeC7TJ63NlV5XHrD7n89v+noEj5m9Uh6VWG4KXO4lboPstK08jL+B
xzXmAKNYU9Tuy6cgcu5T23Ttqh7CupuqWrBcb0MHdktZYP1h3MFzdOd/NiCAERZE
e1njAgMBAAGjIzAhMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MA0G
CSqGSIb3DQEBCwUAA4IBAQAR6+r7pllsrXEYKjpr+LB1iIVSEgFOMi4WP7XFXDGS
i1Uxnn42iG7SmdzEs5WBz5m0uDI16W8y87hF/7pB8lduDlmkDNh95vnW8X+AB5GS
VWPK9Dd6BOHEMtK+4uG1gc/6h4ncT+UwTYY70P8DInQzTuB6mFmi4SE7S3vNaGC5
41YWaSVaSGmwhLs2DAYcTzDfEfcGaJsN0gZFc8LX6dwoEAq7PL5ttSgdehSk2FZq
y1F/DS02OAfdoWSk8S3XOYumUX3U/UwarfqfijFrTmvZITXTaOvNkDH70YtAevpe
jEWB5B+LCipcVx0VoUrFOrYrpcdwSZyQCJHmWix7hcl8
-----END CERTIFICATE-----
CERT

    cert = OpenSSL::X509::Certificate.new(cert_with_ip_in_cn_pem)
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "1.2.3.5")).to(eq(false))
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "1.2.3.4")).to(eq(true))
  end

  it 'continues to fail for invalid certificates with CN that has IPv6' do
    cert_with_ipv6_in_cn_pem = <<-CERT
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIQapTtOngI7Ba0RfgP/3/qKDANBgkqhkiG9w0BAQsFADBY
MQwwCgYDVQQGEwNVU0ExFjAUBgNVBAoTDUNsb3VkIEZvdW5kcnkxMDAuBgNVBAMT
JzIwMDE6NDg2MDo0ODYwOjAwMDA6MDAwMDowMDAwOjAwMDA6ODg4ODAeFw0xODAx
MjcwMTM0MjVaFw0xOTAxMjcwMTM0MjVaMFgxDDAKBgNVBAYTA1VTQTEWMBQGA1UE
ChMNQ2xvdWQgRm91bmRyeTEwMC4GA1UEAxMnMjAwMTo0ODYwOjQ4NjA6MDAwMDow
MDAwOjAwMDA6MDAwMDo4ODg4MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
AQEAumlQxSJha6e8eDuzy+UYltUfOBd1tp+HqkQBTj4NbchwA1LJ7gijX651hBbg
f2WOpaWRqOlv+Mrlrr1cdMbbzaOxCW+srYL0oxwkRfsxyP/R024qNQlqh5pH/PAR
hb5DLx34oY9wOpoTOAkbIejnvMWbGAROADIru61L5kRYCrGqJbE+sm1U8v1p5q+s
pMwyjaPCk7jX4wQbkrl/1v4Y/OTutTvZUWog2P2ux87Z9fEgmkiHPXyWn0CKsnBZ
UngwegAI9enzRtYxJrMU2HS6pU6gA+bf9/brQeWM8jUi7qM4ojAFVTZw5TmXH+jD
pIOS/lcIcckb2wVl+rByfF0TtwIDAQABoyMwITAOBgNVHQ8BAf8EBAMCAQYwDwYD
VR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEATgDOdZrUTksFWRRV/v/P
yrTLq6UB3Kskr5F98DDKdyzbU4ZSy6XgMkAj3l/ZMZQ6aJ59Ti9W5vNo0jycM+Gl
YlEjky/WfkiloL3GWW4BMgXWLnCiy9K5IsSu+ypTRGV+aq/Qjn48HOtPSsVbTnxA
bMoUWEwUGWmPT1FVyVudb07zxg1jf8myWVmkVXeBO7f/McqkosWewuB2878O7u2a
DgYqEMOimvIrrtmkWUM7be9jdfQdN+hLDV5gpal3dtGPje2ZAJtN16FMyctHCYYD
3vyn+euWEt/O55UR/ZNat/0HO59HbGOPJ8oMIWrvpiLWWbXoonFKFCMYbVLPoW6g
aQ==
-----END CERTIFICATE-----
CERT

    cert = OpenSSL::X509::Certificate.new(cert_with_ipv6_in_cn_pem)
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "2001:4860:4860:0000:0000:0000:0000:8889")).to(eq(false))
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "2001:4860:4860:0000:0000:0000:0000:8888")).to(eq(true))
  end

  it 'continues to fail for invalid certificates with alt name that has IPv6' do
    cert_with_ipv6_in_alt_name_pem = <<-CERT
-----BEGIN CERTIFICATE-----
MIIDSzCCAjOgAwIBAgIRANsunSSUqxwvYCczA0O6cr8wDQYJKoZIhvcNAQELBQAw
MzEMMAoGA1UEBhMDVVNBMRYwFAYDVQQKEw1DbG91ZCBGb3VuZHJ5MQswCQYDVQQD
EwJjYTAeFw0xODAxMjcwMTQ2NDFaFw0xOTAxMjcwMTQ2NDFaMDsxDDAKBgNVBAYT
A1VTQTEWMBQGA1UEChMNQ2xvdWQgRm91bmRyeTETMBEGA1UEAxMKY24taW4tY2Vy
dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMFiYA0XLM9/ly1BibMH
MO5XDn75Ue7Locd9Uua7gsA85ShcQHu2tUkhIdKb/oooHldOzihMWSyTLSs3cs3N
FDzSmkHIgXAN9yYFLtTzqsI8HtdMwp3HRtfn7XgJqujwdU6CopPRzxZPAj4kg+r4
7S5OTx0EYt1WzWSFPEz7MAbampsI5IZ6pxuZFhCzTbtUr9VnHtXQs9MJHtA1vLZW
OUzBfyyx//lGWPnmoc+c3WcBby3eqCZuQ8Tv0DtNdj4J2wS4GYxei1uZr/qr0MpN
9LnCRYIbtHtWJSUGeApaHF3E2hiq/BQDQ1OpxQhDw1fhe+ImBnP3Pei4oby7oCsm
ftcCAwEAAaNSMFAwDgYDVR0PAQH/BAQDAgWgMBMGA1UdJQQMMAoGCCsGAQUFBwMB
MAwGA1UdEwEB/wQCMAAwGwYDVR0RBBQwEocQIAFIYEhgAAAAAAAAAAAAiDANBgkq
hkiG9w0BAQsFAAOCAQEAETzrzScHpzPkLTzk8DETL8CyayATDkPb1VUUGlW9SXgZ
qwVwXBYDyEfUxB9u4te3kIjc2rm32ihHZZ0dRnroj7zhZsfPTThbeU4xvN4sdnTD
88ulEiVW0D5kdA0I4r7ZbAQBlM9nKrygohq2A3BxyDCFfoBubfNJV2xBhocNl1m0
hTE4K0Pskz0UJ0UlPVt4VMjuVV6c64XsOls6Yc5wiYo3lB0DMJdJzFWBb1dQLETR
Kukd1rgO8MF4IqWEavhYVaRReOzHmvk5mtDgAzVTu6Y3svsRc9ckHpKpXSmRve7c
UNRKD1ocfJiGNGr6edDv/iErOmyQLda5KP5TiCMYaA==
-----END CERTIFICATE-----
CERT

    cert = OpenSSL::X509::Certificate.new(cert_with_ipv6_in_alt_name_pem)
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "2001:4860:4860:0000:0000:0000:0000:89")).to(eq(false)) # not in alt
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "2001:4860:4860:0:0:0:0:88")).to(eq(true)) # in alt
    expect(OpenSSL::SSL.verify_certificate_identity(cert, "2001:4860:4860:0000:0000:0000:0000:88")).to(eq(true)) # in alt
  end
end
