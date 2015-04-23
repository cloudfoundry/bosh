require 'spec_helper'

describe 'drain', type: :integration do
  describe 'static drain' do
    with_reset_sandbox_before_all

    before(:all) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash['resource_pools'].first['size'] = 1

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      manifest_hash['jobs'][0]['persistent_disk'] = 100
      manifest_hash['properties'] ||= {}
      manifest_hash['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    it 'runs the drain script on a job if drain script is present' do
      drain_log = director.vm('foobar/0').read_file('drain-test.log')
      expect(drain_log).to eq("job_shutdown hash_unchanged\n1\n")
    end

    it 'sets BOSH_JOB_STATE and BOSH_JOB_NEXT_STATE env vars with changed values' do
      drain_log = director.vm('foobar/0').read_file('drain-job-state.log')
      expect(drain_log).to include('BOSH_JOB_STATE={"persistent_disk":0}')
      expect(drain_log).to include('BOSH_JOB_NEXT_STATE={"persistent_disk":100}')
    end
  end

  describe 'dynamic drain' do
    with_reset_sandbox_before_all

    before(:all) do
      cloud_config_hash = Bosh::Spec::Deployments.simple_cloud_config
      cloud_config_hash['resource_pools'].first['size'] = 1

      manifest_hash = Bosh::Spec::Deployments.simple_manifest
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['jobs'][0]['instances'] = 1
      manifest_hash['properties'] ||= {}
      manifest_hash['properties']['drain_type'] = 'dynamic'

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      manifest_hash['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    it 'retries after the appropriate amount of time' do
      drain_log = director.vm('foobar/0').read_file('drain-test.log')
      drain_times = drain_log.split.map(&:to_i)
      expect(drain_times.size).to eq(3)
      expect(drain_times[1] - drain_times[0]).to be >= 3
      expect(drain_times[2] - drain_times[1]).to be >= 2
    end
  end
end
