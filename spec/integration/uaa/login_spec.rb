require 'spec_helper'

describe 'Logging into a director with UAA authentication', type: :integration do
  context 'with properly configured UAA' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}")
      bosh_runner.run('logout')
    end

    it 'logs in successfully using password' do
      bosh_runner.run_interactively("login --ca-cert #{current_sandbox.certificate_path}") do |runner|
        expect(runner).to have_output 'Email:'
        runner.send_keys 'marissa'
        expect(runner).to have_output 'Password:'
        runner.send_keys 'koala'
        expect(runner).to have_output 'One Time Code'
        runner.send_keys '' # UAA only uses this for SAML, but always prompts for it
        expect(runner).to have_output "Logged in as `marissa'"
      end

      output = bosh_runner.run('status')
      expect(output).to match /marissa/
    end

    it 'logs in successfully using client id and client secret' do
      bosh_runner.run_interactively(
        "login --ca-cert #{current_sandbox.certificate_path}",
        { 'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret' }
      ) do |runner|
        expect(runner).to have_output "Logged in as `test'"
      end
    end

    it 'fails to log in when incorrect credentials were provided' do
      bosh_runner.run_interactively("login --ca-cert #{current_sandbox.certificate_path}") do |runner|
        expect(runner).to have_output 'Email:'
        runner.send_keys 'fake'
        expect(runner).to have_output 'Password:'
        runner.send_keys 'fake'
        expect(runner).to have_output 'One Time Code'
        runner.send_keys ''
        expect(runner).to have_output 'Failed to log in: Bad credentials'
      end
      output = bosh_runner.run('status')
      expect(output).to match /not logged in/
    end

    it 'fails to log in  with a useful message when cli fails to validate server and no cert was specified' do
      bosh_runner.run_interactively('login') do |runner|
        expect(runner).to have_output 'Invalid SSL Cert. Use --ca-cert to specify SSL certificate'
      end
    end

    it 'it fails to log in if the director cert is invalid' do
      invalid_ca_cert = <<CERT
-----BEGIN CERTIFICATE-----
MIICsjCCAhugAwIBAgIJAM9y8pcTt1bMMA0GCSqGSIb3DQEBBQUAMEUxCzAJBgNV
BAYTAkFVMRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYDVQQKExhJbnRlcm5ldCBX
aWRnaXRzIFB0eSBMdGQwIBcNMTUwMzMwMTY0OTA5WhgPMjI4OTAxMTExNjQ5MDla
MEUxCzAJBgNVBAYTAkFVMRMwEQYDVQQIEwpTb21lLVN0YXRlMSEwHwYDVQQKExhJ
bnRlcm5ldCBXaWRnaXRzIFB0eSBMdGQwgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJ
AoGBANEz3Vft3Px81iaBzk2cNMEnHGbpYU+Rmd1ubvq2fiLbumZ5j7mVDU6VQFYo
cMGdG9as2DfXrIseOAxXS3Py/QOSRBoAskRSwcxfw2eYREFgiROUYYi/uiKPgnd4
Q3aqjiT+DQVI+nJ0Ll+TxiZvJHRa+VIIvLxmMqOupr2QGM41AgMBAAGjgacwgaQw
HQYDVR0OBBYEFMx+qGtFmhIY9uYHkS1zJn3DsjE5MHUGA1UdIwRuMGyAFMx+qGtF
mhIY9uYHkS1zJn3DsjE5oUmkRzBFMQswCQYDVQQGEwJBVTETMBEGA1UECBMKU29t
ZS1TdGF0ZTEhMB8GA1UEChMYSW50ZXJuZXQgV2lkZ2l0cyBQdHkgTHRkggkAz3Ly
lxO3VswwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQUFAAOBgQA8H7a44zRSCZkp
QwR/eC1kaNEHhZ0sSi7R5wWch9fCi5b0WLWYszErjcae55idpWaBKMqKQSJwS5Yw
pS7LCyKNPxUs7UCTkGrGOyFC9vnzwi6ZrrlmDS8bcfQM8r3LVUfuTuGyB2MN0C+X
FMshbBhc5OxwmjW+WMSJ4R6qzm4gjA==
-----END CERTIFICATE-----
CERT

      Dir.mktmpdir do |tmpdir|
        cert_path = File.join(tmpdir, 'invalid_cert.pem')
        File.write(cert_path, invalid_ca_cert)

        bosh_runner.run_interactively("login --ca-cert #{cert_path}") do |runner|
          expect(runner).to have_output 'Invalid SSL Cert'
        end
      end
    end
  end

  context 'when UAA is configured with wrong certificate' do
    with_reset_sandbox_before_each(user_authentication: 'uaa', ssl_mode: 'wrong-ca')

    before do
      bosh_runner.run("target #{current_sandbox.director_url}")
    end

    it 'fails to log in when incorrect credentials were provided' do
      bosh_runner.run_interactively("login --ca-cert #{current_sandbox.certificate_path}") do |runner|
        expect(runner).to have_output 'Invalid SSL Cert'
      end
    end
  end
end
