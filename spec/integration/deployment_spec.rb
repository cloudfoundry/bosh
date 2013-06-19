require 'spec_helper'

describe 'deployment integrations' do
  include IntegrationExampleGroup

  describe 'drain' do
    it 'runs the drain script on a job if drain script is present' do
      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')

      run_bosh('create release', TEST_RELEASE_DIR)
      run_bosh('upload release', TEST_RELEASE_DIR)

      run_bosh("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['release']['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['resource_pools'][0]['size'] = 1

      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('deploy')
      deployment_manifest.delete

      manifest_hash['properties'] ||= {}
      manifest_hash['properties']['test_property'] = 0
      deployment_manifest = yaml_file('simple', manifest_hash)
      run_bosh("deployment #{deployment_manifest.path}")
      run_bosh('deploy')

      drain_output = Dir["#{current_sandbox.agent_tmp_path}/agent-base-dir-*/*"].detect {|f| File.basename(f) == 'drain-test.log' }
      expect(File.read(drain_output)).to eq "job_unchanged hash_changed\n1\n"
    end
  end

end