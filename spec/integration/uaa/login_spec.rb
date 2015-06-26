require 'spec_helper'

describe 'Logging into a director with UAA authentication', type: :integration do
  context 'with properly configured UAA' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    before do
      bosh_runner.run("target #{current_sandbox.director_url} --ca-cert #{current_sandbox.certificate_path}")
      bosh_runner.run('logout')
    end

    it 'logs in successfully using password' do
      bosh_runner.run_interactively('login') do |runner|
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

      # test we are not getting auth error
      # bosh vms exits with non-0 status if there are no vms
      output = bosh_runner.run('vms', failure_expected: true)
      expect(output).to match /No deployments/
    end

    it 'can access director using client id and client secret' do
      client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
      output = bosh_runner.run('status', env: client_env)
      expect(output).to match /User.*test/

      # test we are not getting auth error
      # bosh vms exits with non-0 status if there are no vms
      output = bosh_runner.run('vms', env: client_env, failure_expected: true)
      expect(output).to match /No deployments/

      # no creds, no dice
      output = bosh_runner.run('vms', failure_expected: true)
      expect(output).to match /Please log in first/
    end

    it 'can login with director uuid scope and director uuid authorities' do
      client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}

      output = bosh_runner.run('deployments', env: client_env, failure_expected: true)
      expect(output).to match /No deployments/
    end

    it 'refreshes the token when running long command' do
      client_env = {'BOSH_CLIENT' => 'short-lived-client', 'BOSH_CLIENT_SECRET' => 'short-lived-secret'}
      _, exit_code = deploy_from_scratch(no_login: true, env: client_env, return_exit_code: true)
      expect(exit_code).to eq(0)
    end

    it 'fails to log in when incorrect credentials were provided' do
      bosh_runner.run_interactively('login') do |runner|
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
      bosh_runner.run("target #{current_sandbox.director_url}")
      bosh_runner.run_interactively('login') do |runner|
        expect(runner).to have_output 'Invalid SSL Cert. Use --ca-cert option when setting target to specify SSL certificate'
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

        bosh_runner.run("target #{current_sandbox.director_url} --ca-cert #{cert_path}")
        bosh_runner.run_interactively("login") do |runner|
          expect(runner).to have_output 'Invalid SSL Cert'
        end
      end
    end

    context 'when user has read access' do
      it 'can only access read resources' do
        client_env = {'BOSH_CLIENT' => 'read-access', 'BOSH_CLIENT_SECRET' => 'secret'}
        output = deploy_from_scratch(no_login: true, env: client_env, failure_expected: true)
        expect(output).to include(`Not authorized: '/deployments' requires one of the scopes: bosh.admin, bosh.deadbeef.admin`)

        output = bosh_runner.run('deployments', env: client_env, failure_expected: true)
        expect(output).to match /No deployments/
      end

      it 'can see list of vms' do
        client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
        deploy_from_scratch(no_login: true, env: client_env)

        client_env = {'BOSH_CLIENT' => 'read-access', 'BOSH_CLIENT_SECRET' => 'secret'}
        vms = director.vms(env: client_env)
        expect(vms.size).to eq(3)
      end

      it 'can only access task default logs' do
        admin_client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
        read_client_env = {'BOSH_CLIENT' => 'read-access', 'BOSH_CLIENT_SECRET' => 'secret'}
        create_and_upload_test_release(env: admin_client_env)

        output = bosh_runner.run('task latest', env: read_client_env)
        expect(output).to match /release has been created/

        output = bosh_runner.run('task latest --debug', env: read_client_env, failure_expected: true)
        expect(output).to match /Not authorized: '\/tasks\/[0-9]+\/output' requires one of the scopes: bosh.admin, bosh.deadbeef.admin/

        output = bosh_runner.run('task latest --cpi', env: read_client_env, failure_expected: true)
        expect(output).to match /Not authorized: '\/tasks\/[0-9]+\/output' requires one of the scopes: bosh.admin, bosh.deadbeef.admin/

        output = bosh_runner.run('task latest --debug', env: admin_client_env)
        expect(output).to match /DEBUG/

        output = bosh_runner.run('task latest --cpi', env: admin_client_env)
        expect(output).to match /Task \d* done/
      end
    end

    context 'when user does not have access' do
      it 'can only access status endpoint' do
        client_env = {'BOSH_CLIENT' => 'no-access', 'BOSH_CLIENT_SECRET' => 'secret'}
        output = bosh_runner.run('status', env: client_env)
        expect(output).to match /User.*no-access/

        # AuthError because verification is happening on director side
        output = bosh_runner.run('vms', env: client_env, failure_expected: true)
        expect(output).to include(`Not authorized: '/deployments' requires one of the scopes: bosh.admin, bosh.deadbeef.admin, bosh.read, bosh.deadbeef.read`)
      end
    end

    describe 'health monitor' do
      before { current_sandbox.health_monitor_process.start }
      after { current_sandbox.health_monitor_process.stop }

      it 'resurrects vm' do
        client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
        deploy_from_scratch(no_login: true, env: client_env)

        original_vm = director.vm('foobar/0', env: client_env)
        original_vm.kill_agent
        resurrected_vm = director.wait_for_vm('foobar/0', 300, env: client_env)
        expect(resurrected_vm.cid).to_not eq(original_vm.cid)
      end
    end
  end

  context 'when UAA is configured with asymmetric key' do
    with_reset_sandbox_before_each(user_authentication: 'uaa', uaa_encryption: 'asymmetric')

    before do
      bosh_runner.run("target #{current_sandbox.director_url} --ca-cert #{current_sandbox.certificate_path}")
      bosh_runner.run('logout')
    end

    it 'logs in successfully' do
      client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
      output = bosh_runner.run('status', env: client_env)
      expect(output).to match /User.*test/

      # test we are not getting auth error
      # bosh vms exits with non-0 status if there are no vms
      output = bosh_runner.run('vms', env: client_env, failure_expected: true)
      expect(output).to match /No deployments/
    end
  end

  context 'when UAA is configured with wrong certificate' do
    with_reset_sandbox_before_each(user_authentication: 'uaa', ssl_mode: 'wrong-ca')

    before do
      bosh_runner.run("target #{current_sandbox.director_url} --ca-cert #{current_sandbox.certificate_path}")
    end

    it 'fails to log in when incorrect credentials were provided' do
      bosh_runner.run_interactively('login') do |runner|
        expect(runner).to have_output 'Invalid SSL Cert'
      end
    end
  end
end
