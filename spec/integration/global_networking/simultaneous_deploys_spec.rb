require 'spec_helper'

describe 'simultaneous deploys', type: :integration do
  with_reset_sandbox_before_each

  let(:first_manifest_hash) do
    Bosh::Spec::Deployments.simple_manifest
  end

  let(:second_manifest_hash) do
    Bosh::Spec::Deployments.simple_manifest.merge('name' => 'second')
  end

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config(cloud_config_hash: cloud_config)
  end

  def start_deploy(manifest)
    output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)
    return Bosh::Spec::OutputParser.new(output).task_id('running')

  end

  context 'dynamic IPs' do
    context 'when there are enough IPs for two deployments' do
      let(:cloud_config) do
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config['networks'].first['subnets'] = [{
            'range' => '192.168.1.0/28',
            'gateway' => '192.168.1.1',
            'dns' => [],
            'static' => [],
            'reserved' => ['192.168.1.8-192.168.1.15'],
            'cloud_properties' => {},
          }]
        cloud_config
      end

      before do
        first_task_id = start_deploy(first_manifest_hash)
        second_task_id = start_deploy(second_manifest_hash)

        output, success = director.task(first_task_id)
        expect(success).to(be(true), "task failed: #{output}")

        output, success = director.task(second_task_id)
        expect(success).to(be(true), "task failed: #{output}")
      end

      it 'allocates different IP to another deploy' do
        first_deployment_ips = director.vms(first_manifest_hash['name']).map(&:ips).flatten
        second_deployment_ips = director.vms(second_manifest_hash['name']).map(&:ips).flatten
        expect(first_deployment_ips + second_deployment_ips).to match_array(
          ['192.168.1.2', '192.168.1.3', '192.168.1.4', '192.168.1.5', '192.168.1.6', '192.168.1.7']
        )
      end
    end

    context 'when there are not enough IPs for two deployments' do
      let(:cloud_config) do
        cloud_config = Bosh::Spec::Deployments.simple_cloud_config
        cloud_config['networks'].first['subnets'] = [{
            'range' => '192.168.1.0/28',
            'gateway' => '192.168.1.1',
            'dns' => [],
            'static' => [],
            'reserved' => ['192.168.1.6-192.168.1.15'],
            'cloud_properties' => {},
          }]
        cloud_config
      end

      it 'fails one of deploys' do
        first_task_id = start_deploy(first_manifest_hash)
        second_task_id = start_deploy(second_manifest_hash)

        first_output, first_success = director.task(first_task_id)
        second_output, second_success = director.task(second_task_id)
        expect([first_success, second_success]).to match_array([true, false])
        expect(first_output + second_output).to include("asked for a dynamic IP but there were no more available")
      end
    end
  end
end
