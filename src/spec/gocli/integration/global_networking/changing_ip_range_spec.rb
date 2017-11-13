require_relative '../../spec_helper'

describe 'Changing ip ranges', type: :integration do
  with_reset_sandbox_before_each

  before do
    create_and_upload_test_release
    upload_stemcell
  end

  describe 'shifting the IP range for a job' do
    it 'should recreate VMs outside of the range in the new range, but not touch VMs that are ok' do
      cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2)
      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2, job: 'foobar_without_packages')
      upload_cloud_config(cloud_config_hash: cloud_config)
      deploy_simple_manifest(manifest_hash: deployment_manifest)

      instances = director.instances
      original_instance_0 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '0' }
      original_instance_1 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '1' }

      expect(original_instance_0.ips).to contain_exactly('192.168.1.2')
      expect(original_instance_1.ips).to contain_exactly('192.168.1.3')

      new_cloud_config = Bosh::Spec::NetworkingManifest.cloud_config(available_ips: 2, shift_ip_range_by: 1)
      upload_cloud_config(cloud_config_hash: new_cloud_config)

      deploy_simple_manifest(manifest_hash: deployment_manifest)

      instances = director.instances
      new_instance_0 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '0' }
      new_instance_1 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '1' }

      expect(new_instance_0.ips).to contain_exactly('192.168.1.4')
      expect(new_instance_1.ips).to contain_exactly('192.168.1.3')

      expect(new_instance_0.vm_cid).to_not eq(original_instance_0.vm_cid)
      expect(new_instance_1.vm_cid).to eq(original_instance_1.vm_cid)
    end

    context 'using legacy network configuration (no cloud config)' do
      it 'should recreate VMs outside of the range in the new range, but not touch VMs that are ok' do
        deployment_manifest = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(template: 'foobar_without_packages', instances: 2, available_ips: 2)
        deploy_simple_manifest(manifest_hash: deployment_manifest)

        instances = director.instances
        original_instance_0 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '0' }
        original_instance_1 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '1' }

        expect(original_instance_0.ips).to contain_exactly('192.168.1.2')
        expect(original_instance_1.ips).to contain_exactly('192.168.1.3')

        deployment_manifest = Bosh::Spec::NetworkingManifest.legacy_deployment_manifest(template: 'foobar_without_packages', instances: 2, available_ips: 2, shift_ip_range_by: 1)
        deploy_simple_manifest(manifest_hash: deployment_manifest)

        instances = director.instances
        new_instance_0 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '0' }
        new_instance_1 = instances.find { |instance| instance.job_name == 'foobar' && instance.index == '1' }

        expect(new_instance_0.ips).to contain_exactly('192.168.1.4')
        expect(new_instance_1.ips).to contain_exactly('192.168.1.3')

        expect(new_instance_0.vm_cid).to_not eq(original_instance_0.vm_cid)
        expect(new_instance_1.vm_cid).to eq(original_instance_1.vm_cid)
      end
    end
  end
end
