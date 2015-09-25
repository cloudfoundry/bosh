require 'spec_helper'

describe 'Changing ip ranges', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
  end

  describe 'shifting the IP range for a job' do
    it 'should recreate VMs outside of the range in the new range, but not touch VMs that are ok' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2, template: 'foobar_without_packages')
      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      vms = director.vms
      original_instance_0 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '0' }
      original_instance_1 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '1' }

      expect(original_instance_0.ips).to eq('192.168.1.2')
      expect(original_instance_1.ips).to eq('192.168.1.3')

      new_cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: new_cloud_config)

      deploy_simple_manifest(manifest_hash: deployment_manifest)

      vms = director.vms
      new_instance_0 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '0' }
      new_instance_1 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '1' }

      expect(new_instance_0.ips).to eq('192.168.1.4')
      expect(new_instance_1.ips).to eq('192.168.1.3')

      expect(new_instance_0.cid).to_not eq(original_instance_0.cid)
      expect(new_instance_1.cid).to eq(original_instance_1.cid)
    end

    context 'using legacy network configuration (no cloud config)' do
      it 'should recreate VMs outside of the range in the new range, but not touch VMs that are ok' do
        deployment_manifest = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(template: 'foobar_without_packages', instances: 2, available_ips: 2)
        deploy_simple_manifest(manifest_hash: deployment_manifest)

        vms = director.vms
        original_instance_0 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '0' }
        original_instance_1 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '1' }

        expect(original_instance_0.ips).to eq('192.168.1.2')
        expect(original_instance_1.ips).to eq('192.168.1.3')

        deployment_manifest = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(template: 'foobar_without_packages', instances: 2, available_ips: 2, shift_ip_range_by: 1)
        deploy_simple_manifest(manifest_hash: deployment_manifest)

        vms = director.vms
        new_instance_0 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '0' }
        new_instance_1 = vms.find { |vm| vm.job_name == 'foobar' && vm.index == '1' }

        expect(new_instance_0.ips).to eq('192.168.1.4')
        expect(new_instance_1.ips).to eq('192.168.1.3')

        expect(new_instance_0.cid).to_not eq(original_instance_0.cid)
        expect(new_instance_1.cid).to eq(original_instance_1.cid)
      end
    end
  end
end
