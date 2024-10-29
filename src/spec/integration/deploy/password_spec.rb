require 'spec_helper'

describe 'password', type: :integration do
  with_reset_sandbox_before_each

  context 'deployment manifest specifies VM password' do
    context 'director deployment does not set generate_vm_passwords' do
      it 'uses specified VM password' do
        manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
        deploy_from_scratch(manifest_hash: manifest_hash)

        instance = director.instances.first
        agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
        user_password = File.read("#{agent_dir}/bosh/vcap/password")
        root_password = File.read("#{agent_dir}/bosh/root/password")

        expect(user_password).to eq('foobar')
        expect(root_password).to eq('foobar')
      end
    end

    context 'director deployment sets generate_vm_passwords as true' do
      with_reset_sandbox_before_each(generate_vm_passwords: true)
      it 'does not generate a random password and instead uses specified VM password' do
        manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].first['env'] = { 'bosh' => { 'password' => 'foobar' } }
        deploy_from_scratch(manifest_hash: manifest_hash)

        instance = director.instances.first
        agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(instance.vm_cid)
        user_password = File.read("#{agent_dir}/bosh/vcap/password")
        root_password = File.read("#{agent_dir}/bosh/root/password")

        expect(user_password).to eq('foobar')
        expect(root_password).to eq('foobar')
      end
    end
  end

  context 'deployment manifest does not specify VM password' do
    let(:cloud_config_hash) do
      Bosh::Spec::DeploymentManifestHelper.simple_cloud_config
    end

    context 'director deployment sets generate_vm_passwords as true' do
      with_reset_sandbox_before_each(generate_vm_passwords: true)
      it 'generates a random unique password for each vm' do
        manifest_hash = Bosh::Spec::DeploymentManifestHelper.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'].first['instances'] = 2
        deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

        first_instance = director.instances[0]
        first_agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(first_instance.vm_cid)
        first_user_password = File.read("#{first_agent_dir}/bosh/vcap/password")
        first_root_password = File.read("#{first_agent_dir}/bosh/root/password")

        second_instance = director.instances[1]
        second_agent_dir = current_sandbox.cpi.agent_dir_for_vm_cid(second_instance.vm_cid)
        second_user_password = File.read("#{second_agent_dir}/bosh/vcap/password")
        second_root_password = File.read("#{second_agent_dir}/bosh/root/password")

        expect(first_user_password.length).to_not eq(0)
        expect(first_root_password.length).to_not eq(0)

        expect(second_user_password.length).to_not eq(0)
        expect(second_root_password.length).to_not eq(0)

        expect(first_user_password).to_not eq(second_user_password)
        expect(first_root_password).to_not eq(second_root_password)
      end
    end
  end
end
