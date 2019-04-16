require_relative '../../spec_helper'

# TODO: Remove test when done removing v1 manifest support
xdescribe 'health_monitor with legacy manifest', type: :integration, hm: true do
  context 'if fix_stateful_nodes director option is not set' do
    with_reset_sandbox_before_each(director_fix_stateful_nodes: false)
    with_reset_hm_before_each

    it 'resurrects stateless nodes' do
      deploy_from_scratch({legacy: true, manifest_hash: Bosh::Spec::Deployments.legacy_manifest})

      original_instance = director.instance('foobar', '0', deployment_name: 'simple')
      original_instance.kill_agent
      resurrected_instance = director.wait_for_vm('foobar', '0', 300, deployment_name: 'simple')
      expect(resurrected_instance.vm_cid).to_not eq(original_instance.vm_cid)
    end
  end
end
