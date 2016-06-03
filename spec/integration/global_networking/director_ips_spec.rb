require 'spec_helper'

describe 'director ips', type: :integration do

  with_reset_sandbox_before_each({director_ips: ['192.168.1.2']})

  let(:cloud_config_hash) do
    Bosh::Spec::Deployments.simple_cloud_config
  end

  let(:simple_manifest) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'].first['instances'] = 1
    manifest_hash
  end

  context 'when director is deployed to the same subnet where it is deploying vms' do
    before do
      target_and_login
      create_and_upload_test_release
      upload_stemcell
    end

    it "does not give out it's own address" do
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      deploy_simple_manifest(manifest_hash: simple_manifest)
      expect(director.vms.first.ips).to eq('192.168.1.3')
    end
  end
end
