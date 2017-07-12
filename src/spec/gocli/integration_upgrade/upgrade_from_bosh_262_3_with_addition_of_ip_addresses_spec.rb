require_relative '../spec_helper'

describe 'upgraded director has local_dns enabled and supports the ip_addresses flag for links', type: :upgrade do
  with_reset_sandbox_before_each(test_initial_state: 'bosh-v262.3-2e94c7cdc76928162d346863270690dfec8c70ee', drop_database: true, local_dns: {'enabled' => true})

  before do
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, preserve: false)
    bosh_runner.run_in_dir('create-release --force --version=8.9.10', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload-release', ClientSandbox.links_release_dir)
  end

  let(:manifest_hash) do
    {
      'name' => 'simple_consumer',
      'releases' => [{'name' => 'bosh-release', 'version' => 'latest'}],
      'update' => {
        'canaries' => 2,
        'canary_watch_time' => 4000,
        'max_in_flight' => 1,
        'update_watch_time' => 20
      },
      'instance_groups' => [{
        'name' => 'ig_consumer',
        'jobs' => [{
          'name' => 'consumer',
          'consumes' => consumes
        }],
        'instances' => 1,
        'networks' => [{'name' => 'private'}],
        'vm_type' => 'small',
        'persistent_disk_type' => 'small',
        'azs' => ['z1'],
        'stemcell' => 'default'
      }],
      'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
    }
  end

  context 'when there is a consumer deployment made by the new director which uses links from a provider deployment deployed by old director' do

    context 'when ip_address flag is not set by consumer link' do
      let (:consumes) {{
        'provider' => {
          'from' => 'provider_link',
          'deployment' => 'simple'
        }
      }}

      it 'gives a dns address for the link address' do
        deploy_simple_manifest(manifest_hash: manifest_hash)
        instance = director.instance('ig_consumer', '0', deployment_name: 'simple_consumer', json: true)
        hash = YAML.load(instance.read_job_template('consumer', 'config.yml'))
        expect(hash['provider_link_0_address']).to match /.ig-provider.private.simple.bosh/
      end
    end

    context 'when ip_address flag is set to false for consumer link' do
      let (:consumes) {{
        'provider' => {
          'from' => 'provider_link',
          'deployment' => 'simple',
          'ip_addresses' => false
        }
      }}

      it 'gives a dns address for the link address' do
        deploy_simple_manifest(manifest_hash: manifest_hash)
        instance = director.instance('ig_consumer', '0', deployment_name: 'simple_consumer', json: true)
        hash = YAML.load(instance.read_job_template('consumer', 'config.yml'))
        expect(hash['provider_link_0_address']).to match /.ig-provider.private.simple.bosh/
      end
    end

    context 'when ip_address flag is set to true for consumer link' do
      let (:consumes) {{
        'provider' => {
          'from' => 'provider_link',
          'deployment' => 'simple',
          'ip_addresses' => true
        }
      }}

      it 'raises an error requesting provider redeployment' do
        output = deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)
        expect(output).to match /Unable to retrieve default network from provider. Please redeploy provider deployment/
      end
    end
  end

  context 'when a provider deployment deployed by old director is started by new director (causing provider deployment link spec to be updated)' do

    before do
      output = scrub_random_ids(parse_blocks(bosh_runner.run('-d simple start', json: true)))
      expect(output).to include('Creating missing vms: ig_provider/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0)')
      expect(output).to include('Updating instance ig_provider: ig_provider/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (0) (canary)')
    end

    context 'when there is a consumer deployment deployed by the new director which uses links from the provider deployment' do

      before do
        puts deploy_simple_manifest(manifest_hash: manifest_hash)
      end

      context 'when ip_address flag is not set by consumer link' do
        let (:consumes) {{
          'provider' => {
            'from' => 'provider_link',
            'deployment' => 'simple'
          }
        }}

        it 'gives a dns address for the link address' do
          instance = director.instance('ig_consumer', '0', deployment_name: 'simple_consumer', json: true)
          hash = YAML.load(instance.read_job_template('consumer', 'config.yml'))
          expect(hash['provider_link_0_address']).to match /.ig-provider.private.simple.bosh/
        end
      end

      context 'when ip_address flag is set to false for consumer link' do
        let (:consumes) {{
          'provider' => {
            'from' => 'provider_link',
            'deployment' => 'simple',
            'ip_addresses' => false
          }
        }}

        it 'gives a dns address for the link address' do
          instance = director.instance('ig_consumer', '0', deployment_name: 'simple_consumer', json: true)
          hash = YAML.load(instance.read_job_template('consumer', 'config.yml'))
          expect(hash['provider_link_0_address']).to match /.ig-provider.private.simple.bosh/
        end
      end

      context 'when ip_address flag is set to true for consumer link' do
        let (:consumes) {{
          'provider' => {
            'from' => 'provider_link',
            'deployment' => 'simple',
            'ip_addresses' => true
          }
        }}

        it 'gives an ip address for the link address' do
          instance = director.instance('ig_consumer', '0', deployment_name: 'simple_consumer', json: true)
          hash = YAML.load(instance.read_job_template('consumer', 'config.yml'))
          expect(hash['provider_link_0_address']).to match /10.10.0.2/
        end
      end
    end
  end
end
