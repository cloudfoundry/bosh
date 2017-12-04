require_relative '../../spec_helper'

describe 'using director with config server disabled', type: :integration do
  with_reset_sandbox_before_each(config_server_enabled: false)

  let(:manifest_hash) do
    {
      'name' => 'simple',
      'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
      'update' => {
        'canaries' => 2,
        'canary_watch_time' => 4000,
        'max_in_flight' => 1,
        'update_watch_time' => 20
      },
      'instance_groups' => [{
        'name' => 'ig_1',
        'templates' => [{
          'name' => 'job_1_with_many_properties',
          'properties' => {
            'gargamel' => {
              'color' => 'evil'
            }
          }
        }],
        'instances' => 1,
        'networks' => [{'name' => 'default'}],
        'properties' => {},
        'vm_type' => 'default',
        'persistent_disk_type' => 'default',
        'azs' => ['z1'],
        'stemcell' => 'default'
      }],
      'stemcells' => [{'alias' => 'default', 'os' => 'toronto-os', 'version' => '1'}]
    }
  end

  let(:cloud_config) do
    {
      'azs' => [{'name' => 'z1'}],
      'compilation' => {
        'az' => 'z1',
        'network' => 'default',
        'workers' => 1,
        'vm_type' => 'default'
      },
      'vm_types' => [{'name' => 'default'}],
      'disk_types' => [
        {
          'name' => 'default',
          'disk_size' => 100,
          'cloud_properties' => {
            'prop' => 'm0'
          }
        }
      ],
      'networks' => [
        {
          'name' => 'default',
          'type' => 'manual',
          'subnets' => [
            {
              'azs' => ['z1'],
              'dns' => ['8.8.8.8'],
              'gateway' => '192.168.4.1',
              'range' => '192.168.4.0/24',
            }
          ]
        }
      ]
    }
  end

  context 'when deployment manifest contains placeholders' do

    before do
      manifest_hash['update']['canaries'] = '((/canaries))'
    end

    it 'raises an error' do
      expect {
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      }.to raise_error(RuntimeError, /Failed to fetch variable '\/canaries' from config server: Director is not configured with a config server/)
    end
  end

  context 'when deployment manifest contains variables' do

    before do
      manifest_hash['variables'] = [
        {'name' => 'admin_password', 'type' => 'password'}
      ]
    end

    it 'raises an error' do
      expect {
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
      }.to raise_error(RuntimeError, /Failed to generate variable '\/TestDirector\/simple\/admin_password' from config server: Director is not configured with a config server/)
    end
  end

  context 'when runtime config contains placeholders used by the deployment' do
    let(:runtime_config) do
      {
        'releases' => [{'name' => 'bosh-release', 'version' => '0.1-dev'}],
        'addons' => [
          {
            'name' => 'addon_job',
            'jobs' => [
              'name' => 'job_2_with_many_properties',
              'release' => 'bosh-release',
              'properties' => {
                'gargamel' => {
                  'color' => '((/color))'
                }
              }
            ]
          }
        ]
      }
    end

    it 'raises an error' do
      expect {
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config, runtime_config_hash: runtime_config)
      }.to raise_error(RuntimeError, /Failed to fetch variable '\/color' from config server: Director is not configured with a config server/)
    end
  end

  context 'when cloud config contains placeholders used by the deployment' do

    context 'when placeholder is in the non cloud-properties section' do
      before do
        cloud_config['vm_types'] = ['((/vm_types))']
      end

      it 'raises an error' do
        expect {
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        }.to raise_error(RuntimeError, /Failed to fetch variable '\/vm_types' from config server: Director is not configured with a config server/)
      end
    end

    context 'when placeholder is in the cloud-properties section' do
      before do
        cloud_config['disk_types'][0]['cloud_properties']['prop'] = '((/prop))'
      end

      it 'raises an error' do
        expect {
          deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)
        }.to raise_error(RuntimeError, /Failed to fetch variable '\/prop' from config server: Director is not configured with a config server/)
      end
    end
  end

  context 'when cpi config contains placeholders' do

    let(:cpi_config) {
      {
        'cpis' => [
          {
            'name' => 'cpi-name',
            'type' => 'cpi-type',
            'properties' => {
              'prop' => '((/prop))'
            }
          }
        ]
      }
    }

    let(:cpi_config_file) {yaml_file('cpi_manifest', cpi_config) }

    before do
      cloud_config['azs'][0]['cpi'] = cpi_config['cpis'][0]['name']
    end

    it 'raises an error' do
      expect {
        bosh_runner.run("update-cpi-config #{cpi_config_file.path}")
      }.to raise_error(RuntimeError, /Failed to fetch variable '\/prop' from config server: Director is not configured with a config server/)
    end
  end
end
