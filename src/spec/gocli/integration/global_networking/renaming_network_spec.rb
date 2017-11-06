require_relative '../../spec_helper'

describe 'migrating networks', type: :integration do
  with_reset_sandbox_before_each

  def deploy_with_ip(manifest, ip, options={})
    deploy_with_ips(manifest, [ip], options)
  end

  def deploy_with_ips(manifest, ips, options={})
    manifest['instance_groups'].first['networks'].first['static_ips'] = ips
    manifest['instance_groups'].first['instances'] = ips.size
    options.merge!(manifest_hash: manifest)
    deploy_simple_manifest(options)
  end

  context 'when network was renamed' do
    before do
      create_and_upload_test_release
      upload_stemcell
    end

    let(:cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.10', '192.168.1.11']
      cloud_config_hash
    end

    let(:renamed_network_cloud_config_hash) do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config
      cloud_config_hash['networks'].first['name'] = 'b'
      cloud_config_hash['compilation']['network'] = 'b'
      cloud_config_hash['networks'].first['subnets'].first['static'] = ['192.168.1.11', '192.168.1.10']
      cloud_config_hash
    end

    let(:simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'].first['static_ips'] = ['192.168.1.11', '192.168.1.10']
      manifest_hash
    end

    let(:renamed_network_simple_manifest) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'].first['instances'] = 2
      manifest_hash['instance_groups'].first['networks'] = [{'name' => 'b'}]
      manifest_hash['instance_groups'].first['networks'].first['static_ips'] = ['192.168.1.10', '192.168.1.11']
      manifest_hash
    end

    it 'it is reusing IP from old instance' do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest)
      instances = director.instances
      expect(instances.size).to eq(2)
      expect(instances.map(&:ips).flatten).to match_array(['192.168.1.10', '192.168.1.11'])

      upload_cloud_config(cloud_config_hash: renamed_network_cloud_config_hash)
      deploy_simple_manifest(manifest_hash: renamed_network_simple_manifest)
      instances = director.instances
      expect(instances.size).to eq(2)
      expect(instances.map(&:ips).flatten).to match_array(['192.168.1.10', '192.168.1.11'])
    end
  end
end
