require 'spec_helper'

describe 'global networking', type: :integration do
  with_reset_sandbox_before_each

  before do
    target_and_login
    create_and_upload_test_release
    upload_stemcell
    upload_cloud_config
  end

  context 'when creating vm for compilation fails' do
    before do
      current_sandbox.cpi.commands.make_create_vm_always_fail
    end

    it 'releases its IP for next deploy' do
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1)
      deploy_simple_manifest(manifest_hash: manifest_hash, failure_expected: true)

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      current_sandbox.cpi.commands.allow_create_vm_to_succeed
      manifest_hash = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: manifest_hash)
      expect(director.vms.map(&:ips)).to contain_exactly('192.168.1.2', '192.168.1.3')
    end
  end

  context 'when compilation fails' do
    it 'releases its IP for next deploy' do
      failing_compilation_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'fails_with_too_much_output')
      deploy_simple_manifest(manifest_hash: failing_compilation_manifest, failure_expected: true)

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      another_deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(name: 'another', instances: 1)
      deploy_simple_manifest(manifest_hash: another_deployment_manifest)
      expect(director.vms.map(&:ips)).to contain_exactly('192.168.1.3')  # 192.168.1.2 is reserved by first deployment
    end
  end

  context 'when director fails to clean up compilation VM' do
    it 'releases its IP on subsequent deploy' do
      long_compilation_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 1, template: 'job_with_blocking_compilation')
      deploy_simple_manifest(manifest_hash: long_compilation_manifest, no_track: true)

      director.wait_for_first_available_vm

      compilation_vm_ips = current_sandbox.cpi.invocations_for_method('create_vm').map do |invocation|
        invocation.inputs['networks']['a']['ip']
      end

      expect(compilation_vm_ips).to eq(['192.168.1.3']) # 192.168.1.2 is reserved for instance

      current_sandbox.director_service.hard_stop
      current_sandbox.director_service.start(current_sandbox.director_config)

      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 2)
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      expect(director.vms.map(&:ips)).to contain_exactly('192.168.1.2', '192.168.1.4')

      deployment_manifest = Bosh::Spec::NetworkingManifest.deployment_manifest(instances: 3)
      deploy_simple_manifest(manifest_hash: deployment_manifest)
      expect(director.vms.map(&:ips)).to contain_exactly('192.168.1.2', '192.168.1.3', '192.168.1.4')
    end
  end
end
