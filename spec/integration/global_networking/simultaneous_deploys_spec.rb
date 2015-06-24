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
  end

  def start_deploy(manifest)
    output = deploy_simple_manifest(manifest_hash: manifest, no_track: true)
    return Bosh::Spec::OutputParser.new(output).task_id('running')
  end

  def deployment_manifest(opts)
    manifest = Bosh::Spec::Deployments.simple_manifest
    manifest['name'] = opts.fetch(:name, 'simple')
    manifest['jobs'].first['instances'] = opts.fetch(:instances, 1)
    manifest
  end

  def cloud_config(opts)
    ip_range = NetAddr::CIDR.create('192.168.1.0/24')
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    ip_to_reserve_from = ip_range.nth(opts.fetch(:available_ips)+2) # first IP is gateway, range is inclusive, so +2
    cloud_config['networks'].first['subnets'] = [{
        'range' => ip_range.to_s,
        'gateway' => ip_range.nth(1),
        'dns' => [],
        'static' => [],
        'reserved' => ["#{ip_to_reserve_from}-#{ip_range.last}"],
        'cloud_properties' => {},
      }]
    cloud_config
  end

  def wait_for_deploy(task_id)
    output, success = director.task(task_id)
    expect(success).to(be(true), "task failed: #{output}")
  end

  context 'when there are enough IPs for two deployments' do
    it 'allocates different IP to another deploy' do
      cloud_config = cloud_config(available_ips: 2)
      first_deployment_manifest = deployment_manifest(name: 'first', instances: 1)
      second_deployment_manifest = deployment_manifest(name: 'second', instances: 1)

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = start_deploy(first_deployment_manifest)
      second_task_id = start_deploy(second_deployment_manifest)

      wait_for_deploy(first_task_id)
      wait_for_deploy(second_task_id)

      first_deployment_ips = director.vms('first').map(&:ips).flatten
      second_deployment_ips = director.vms('second').map(&:ips).flatten
      expect(first_deployment_ips + second_deployment_ips).to match_array(
        ['192.168.1.2', '192.168.1.3']
      )
    end
  end

  context 'when there are not enough IPs for two deployments' do
    it 'fails one of deploys' do
      cloud_config = cloud_config(available_ips: 3)
      first_deployment_manifest = deployment_manifest(name: 'first', instances: 2)
      second_deployment_manifest = deployment_manifest(name: 'second', instances: 2)

      upload_cloud_config(cloud_config_hash: cloud_config)
      first_task_id = start_deploy(first_deployment_manifest)
      second_task_id = start_deploy(second_deployment_manifest)

      first_output, first_success = director.task(first_task_id)
      second_output, second_success = director.task(second_task_id)

      puts first_output + second_output

      expect([first_success, second_success]).to match_array([true, false])
      expect(first_output + second_output).to include("asked for a dynamic IP but there were no more available")
    end
  end
end
