require_relative "../../spec_helper"

describe 'health_monitor: 2', type: :integration, hm: true do
  context 'if fix_stateful_nodes director option is not set' do
    with_reset_sandbox_before_each(director_fix_stateful_nodes: false)
    with_reset_hm_before_each

    # ~6m
    it 'does not resurrect stateful nodes' do
      deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      deployment_hash['instance_groups'][0]['instances'] = 1
      deployment_hash['instance_groups'][0]['persistent_disk'] = 20_480
      deploy_from_scratch(manifest_hash: deployment_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      # wait_for_vm will wait here maximum amount of time!
      director.instance('foobar', '0', deployment_name: 'simple').kill_agent
      expect(director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')).to be_nil
    end
  end

  # ~2m
  context 'if fix_stateful_nodes director option is set' do
    with_reset_sandbox_before_each(director_fix_stateful_nodes: true)
    with_reset_hm_before_each

    it 'resurrects stateful nodes ' do
      deployment_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      deployment_hash['instance_groups'][0]['instances'] = 1
      deployment_hash['instance_groups'][0]['persistent_disk'] = 20_480
      deploy_from_scratch(manifest_hash: deployment_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      original_instance = director.instance('foobar', '0', deployment_name: 'simple')
      original_instance.kill_agent
      resurrected_instance = director.wait_for_vm('foobar', '0', 150, deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
    end
  end
end
