require 'spec_helper'

describe 'global networking', type: :integration do
  before do
    # pending doesn't work in before, but keeping it here so it's greppable
    # pending('cli2: #125442231: switch bosh vms to be per deployment like instances cmd')
  end

  with_reset_sandbox_before_each

  def deploy_with_ip(manifest, ip, options = {})
    deploy_with_ips(manifest, [ip], options)
  end

  def deploy_with_ips(manifest, ips, options = {})
    manifest['instance_groups'].first['networks'].first['static_ips'] = ips
    manifest['instance_groups'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_legacy_with_ips(manifest, ips, options = {})
    manifest['jobs'].first['networks'].first['static_ips'] = ips
    manifest['jobs'].first['instances'] = ips.size
    options[:manifest_hash] = manifest
    deploy_simple_manifest(options)
  end

  def deploy_with_range(deployment_name, range)
    cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
    deploy_simple_manifest(manifest_hash: first_manifest_hash)
  end

  def deploy_with_static_ip(deployment_name, ip, range)
    cloud_config_hash = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, range: range) # 1 for compilation
    cloud_config_hash['networks'].first['subnets'].first['static'] << ip
    upload_cloud_config(cloud_config_hash: cloud_config_hash)

    first_manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(name: deployment_name, instances: 1)
    deploy_with_ips(first_manifest_hash, [ip])
  end
end
