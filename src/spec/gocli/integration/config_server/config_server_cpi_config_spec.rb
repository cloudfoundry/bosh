require_relative '../../spec_helper'

describe 'cpi config', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: true, user_authentication: 'uaa', uaa_encryption: 'asymmetric')

  let(:client_env) { {'BOSH_CLIENT' => 'test', 'BOSH_CLIENT_SECRET' => 'secret', 'BOSH_CA_CERT' => "#{current_sandbox.certificate_path}"} }
  let(:config_server_helper) { Bosh::Spec::ConfigServerHelper.new(current_sandbox, logger)}
  let(:cpi_path) { current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI) }
  let(:valid_cpi_config_file) {yaml_file('cpi_manifest', Bosh::Spec::Deployments.simple_cpi_config_with_variables(cpi_path)) }

  before do
    cloud_config_manifest = yaml_file('cloud_manifest', Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs_and_cpis)
    bosh_runner.run("update-cloud-config #{cloud_config_manifest.path}", include_credentials: false,  env: client_env)
  end

  describe 'when all variables are defined in the config-server' do
    before do
      config_server_helper.put_value('/cpi-someFooVal1-var', 'some-foo-val-1')
      config_server_helper.put_value('/cpi-someBarVal1-var', 'some-bar-val-1')
      config_server_helper.put_value('/cpi-someFooVal2-var', 'some-foo-val-2')
      config_server_helper.put_value('/cpi-someBarVal2-var', 'some-bar-val-2')
    end

    describe 'when multiple cpis are defined' do
      let(:stemcell_filename) { spec_asset('valid_stemcell.tgz') }

      before do
        bosh_runner.run("update-cpi-config #{valid_cpi_config_file.path}", include_credentials: false,  env: client_env)
      end

      it "the fetched cpi config should NOT contain any interpolated values" do
        fetched_cpi_config = bosh_runner.run("cpi-config", include_credentials: false,  env: client_env)

        expect(fetched_cpi_config).to_not include('some-foo-val-1')
        expect(fetched_cpi_config).to_not include('some-bar-val-1')
        expect(fetched_cpi_config).to_not include('some-foo-val-2')
        expect(fetched_cpi_config).to_not include('some-bar-val-2')
      end

      describe 'when stemcell is uploaded' do
        before do
          bosh_runner.run("upload-stemcell #{stemcell_filename}", include_credentials: false,  env: client_env)
        end

        it 'sends the correct interpolated CPI request' do
          invocations = current_sandbox.cpi.invocations

          expect(invocations[0].method_name).to eq('info')
          expect(invocations[0].inputs).to eq(nil)
          expect(invocations[0].context).to include({'someKeyFoo1' => 'some-foo-val-1',
                                                     'someKeyBar1' => 'some-bar-val-1'})
          expect(invocations[2].method_name).to eq('info')
          expect(invocations[2].inputs).to eq(nil)
          expect(invocations[2].context).to include({'someKeyFoo2' => 'some-foo-val-2',
                                                     'someKeyBar2' => 'some-bar-val-2'})

        end

        describe 'when a release is deployed' do
          let(:instance_group) { Bosh::Spec::NewDeployments.simple_instance_group(:azs => ['z1', 'z2']) }
          let(:deployment) { Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge('instance_groups' => [instance_group]) }
          let(:deployment_manifest) { yaml_file('deployment_manifest', deployment) }
          before do
            create_and_upload_test_release(include_credentials: false,  env: client_env)
          end

          it 'deploys successfully' do
            output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple', include_credentials: false, env: client_env)

            expect(output).to include("Using deployment 'simple'")
            expect(output).to include('Succeeded')
          end

          it 'does not print any variable values in the deploy output' do
            deploy_output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple', include_credentials: false,  env: client_env)
            expect(deploy_output).to_not include('some-foo-val-1')
            expect(deploy_output).to_not include('some-bar-val-1')
            expect(deploy_output).to_not include('some-foo-val-2')
            expect(deploy_output).to_not include('some-bar-val-2')
          end

          it 'does not log any variable values in the debug output' do
            deploy_output = bosh_runner.run("deploy #{deployment_manifest.path}", deployment_name: 'simple', include_credentials: false,  env: client_env)

            task_id = deploy_output.match(/^Task (\d+) done$/)[1]

            debug_output = bosh_runner.run("task --debug --event --cpi --result #{task_id}", no_login: true, include_credentials: false, env: client_env)

            expect(debug_output).to_not include('some-foo-val-1')
            expect(debug_output).to_not include('some-bar-val-1')
            expect(debug_output).to_not include('some-foo-val-2')
            expect(debug_output).to_not include('some-bar-val-2')
          end
        end
      end

    end

    describe 'when multiple cpis are defined with some relative variables' do
      let(:invalid_cpi_config_file) do
        cpis_config = Bosh::Spec::Deployments.simple_cpi_config_with_variables(cpi_path)
        cpis_config['cpis'][0]['properties']['someRelKey'] = '((some-rel-val))'
        yaml_file('cpi_manifest', cpis_config)
      end

      it 'returns an error' do
        output, exit_code = bosh_runner.run("update-cpi-config #{invalid_cpi_config_file.path}",
                                            include_credentials: false,  env: client_env,
                                            failure_expected: true,
                                            return_exit_code: true)

        expect(exit_code).to_not eq(0)
        expect(output).to include("Relative paths are not allowed in this context. The following must be be switched to use absolute paths: 'some-rel-val'")
      end
    end
  end

  describe 'when all variables are NOT defined in the config-server' do
    it 'returns an error' do
      output, exit_code = bosh_runner.run("update-cpi-config #{valid_cpi_config_file.path}",
                                          include_credentials: false,
                                          env: client_env,
                                          failure_expected: true,
                                          return_exit_code: true)

      expect(exit_code).to_not eq(0)
      expect(output).to include("Failed to find variable '/cpi-someBarVal1-var' from config server: HTTP Code '404', Error: 'Name '/cpi-someBarVal1-var' not found'")
      expect(output).to include("Failed to find variable '/cpi-someFooVal1-var' from config server: HTTP Code '404', Error: 'Name '/cpi-someFooVal1-var' not found'")
    end
  end
end
