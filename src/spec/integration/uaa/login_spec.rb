require 'spec_helper'

describe 'Logging into a director with UAA authentication', type: :integration do
  context 'with properly configured UAA' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    it 'logs in successfully using password' do
      bosh_runner.run_interactively('log-in', environment_name: current_sandbox.director_url, include_credentials: false) do |runner|
        expect(runner).to have_output 'Email'
        runner.send_keys 'marissa'
        expect(runner).to have_output 'Password'
        runner.send_keys 'koala'
        expect(runner).to have_output 'Successfully authenticated with UAA'
      end

      output = bosh_runner.run('env', environment_name: current_sandbox.director_url, include_credentials: false)
      expect(output).to match(/marissa/)

      _, exit_code = bosh_runner.run('vms', environment_name: current_sandbox.director_url, return_exit_code: true, include_credentials: false)
      expect(exit_code).to eq(0)
    end

    it 'can access director using client id and client secret' do
      client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
      output = bosh_runner.run('env', environment_name: current_sandbox.director_url, include_credentials: false, env: client_env)
      expect(output).to match(/User.*test/)

      _, exit_code = bosh_runner.run('vms', environment_name: current_sandbox.director_url, return_exit_code: true, env: client_env, include_credentials: false)
      expect(exit_code).to eq(0)

      # no creds, no dice
      output = bosh_runner.run('vms', environment_name: current_sandbox.director_url, include_credentials: false, failure_expected: true)
      expect(output).to match(/as anonymous user/)
      expect(output).to match(/Not authorized: '\/deployments'/)
    end

    it 'can login with director uuid scope and director uuid authorities' do
      client_env = {'BOSH_CLIENT' => 'director-access', 'BOSH_CLIENT_SECRET' => 'secret'}

      output = bosh_runner.run('deployments', environment_name: current_sandbox.director_url, env: client_env, include_credentials: false, failure_expected: true)
      expect(output).to match(/0 deployments/)
    end

    it 'refreshes the token when running long command' do
      client_env = {'BOSH_CLIENT' => 'short-lived-client', 'BOSH_CLIENT_SECRET' => 'short-lived-secret'}
      _, exit_code = deploy_from_scratch(
        environment_name: current_sandbox.director_url,
        env: client_env,
        include_credentials: false,
        return_exit_code: true,
        manifest_hash: SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups,
        cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
       )
      expect(exit_code).to eq(0)
    end

    it 'can handle long-running http requests' do
      client_env = {'BOSH_CLIENT' => 'short-lived-client', 'BOSH_CLIENT_SECRET' => 'short-lived-secret'}

      `dd if=/dev/urandom of=#{IntegrationSupport::ClientSandbox.test_release_dir}/src/a/bigfile.txt bs=512 count=604800`
      _, exit_code = create_and_upload_test_release(environment_name: current_sandbox.director_url, env: client_env, include_credentials: false, return_exit_code: true, force: true)

      expect(exit_code).to eq(0)
    end

    it 'fails to log in when incorrect credentials were provided' do
      bosh_runner.run_interactively('log-in', environment_name: current_sandbox.director_url, include_credentials: false) do |runner|
        expect(runner).to have_output 'Email'
        runner.send_keys 'fake'
        expect(runner).to have_output 'Password'
        runner.send_keys 'fake'
        expect(runner).to have_output 'Failed to authenticate with UAA'
      end
      output = bosh_runner.run('env', environment_name: current_sandbox.director_url, include_credentials: false)
      expect(output).to match(/not logged in/)
    end

    it 'fails to log in with a useful message when cli fails to validate server and no cert was specified' do
      pending "FIXME: doesn't seem like bosh requires ca-cert to be provided when doing a log-in command. Maybe makes sense since it's needed for basically everything else."
      bosh_runner.run("env #{current_sandbox.director_url}")
      bosh_runner.run_interactively('log-in', no_ca_cert: true, include_credentials: false) do |runner|
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

        output = bosh_runner.run('vms', environment_name: current_sandbox.director_url, ca_cert: cert_path, failure_expected: true)
        expect(output).to include('x509: certificate signed by unknown authority')
      end
    end

    context 'when user has read access' do
      it 'can see list of vms' do
        client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
        deploy_from_scratch(
          environment_name: current_sandbox.director_url,
          include_credentials: false,
          env: client_env,
          manifest_hash: SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups,
          cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
        )

        client_env = {'BOSH_CLIENT' => 'read-access', 'BOSH_CLIENT_SECRET' => 'secret'}
        instances = director.instances(deployment_name: 'simple', environment_name: current_sandbox.director_url, include_credentials: false, env: client_env)
        expect(instances.size).to eq(3)
      end
    end

    describe 'health monitor', hm: true do
      with_reset_hm_before_each

      it 'resurrects vm' do
        client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
        deploy_from_scratch(
          environment_name: current_sandbox.director_url,
          include_credentials: false,
          env: client_env,
          manifest_hash: SharedSupport::DeploymentManifestHelper.simple_manifest_with_instance_groups,
          cloud_config_hash: SharedSupport::DeploymentManifestHelper.simple_cloud_config,
        )

        original_instance = director.instance('foobar', '0', deployment_name: 'simple', environment_name: current_sandbox.director_url, env: client_env, include_credentials: false)
        original_instance.kill_agent
        resurrected_instance = director.wait_for_vm('foobar', '0', 300, deployment_name: 'simple', environment_name: current_sandbox.director_url, env: client_env, include_credentials: false)
        expect(resurrected_instance).to_not eq(nil)

        expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
      end
    end
  end

  context 'when UAA is configured with asymmetric key' do
    with_reset_sandbox_before_each(user_authentication: 'uaa')

    it 'logs in successfully' do
      client_env = {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret'}
      output = bosh_runner.run('env', environment_name: current_sandbox.director_url, env: client_env, include_credentials: false)
      expect(output).to match(/User.*test/)

      _, exit_code = bosh_runner.run('vms', environment_name: current_sandbox.director_url, env: client_env, return_exit_code: true, include_credentials: false)
      expect(exit_code).to eq(0)
    end
  end
end
