require 'spec_helper'

describe 'hm notifications', hm: true, type: :integration do
  with_reset_sandbox_before_each
  with_reset_hm_before_each

  it 'should not scan & fix the ignored VM' do
    manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
    cloud_config = Bosh::Spec::DeploymentManifestHelper.simple_cloud_config

    manifest_hash['instance_groups'].clear
    manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'foobar1', instances: 2)
    manifest_hash['instance_groups'] << Bosh::Spec::DeploymentManifestHelper.simple_instance_group(name: 'foobar2', instances: 2)

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    orig_instances = director.instances

    ignored_instance = orig_instances.select do |instance|
      instance.instance_group_name == 'foobar1' && instance.index == '0'
    end.first
    foobar1_instance2_orig = orig_instances.select do |instance|
      instance.instance_group_name == 'foobar1' && instance.index == '1'
    end.first
    foobar2_instance1_orig = orig_instances.select do |instance|
      instance.instance_group_name == 'foobar2' && instance.index == '0'
    end.first
    foobar2_instance2_orig = orig_instances.select do |instance|
      instance.instance_group_name == 'foobar2' && instance.index == '1'
    end.first

    bosh_runner.run("ignore #{ignored_instance.instance_group_name}/#{ignored_instance.id}", deployment_name: 'simple')

    ignored_instance.kill_agent
    foobar2_instance1_orig.kill_agent

    director.wait_for_vm('foobar2', '0', 300)

    new_instances = director.instances

    ignored_instance_new = new_instances.select do |instance|
      instance.instance_group_name == 'foobar1' && instance.index == '0'
    end.first
    foobar1_instance2_new = new_instances.select do |instance|
      instance.instance_group_name == 'foobar1' && instance.index == '1'
    end.first
    foobar2_instance1_new = new_instances.select do |instance|
      instance.instance_group_name == 'foobar2' && instance.index == '0'
    end.first
    foobar2_instance2_new = new_instances.select do |instance|
      instance.instance_group_name == 'foobar2' && instance.index == '1'
    end.first

    expect(ignored_instance_new.vm_cid).to      eq(ignored_instance.vm_cid)
    expect(foobar1_instance2_new.vm_cid).to     eq(foobar1_instance2_orig.vm_cid)
    expect(foobar2_instance1_new.vm_cid).to_not eq(foobar2_instance1_orig.vm_cid)
    expect(foobar2_instance2_new.vm_cid).to     eq(foobar2_instance2_orig.vm_cid)

    expect(ignored_instance_new.last_known_state).to eq('unresponsive agent')
  end
end

