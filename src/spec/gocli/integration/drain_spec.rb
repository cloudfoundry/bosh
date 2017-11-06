require_relative '../spec_helper'

describe 'drain', type: :integration do
  let(:deployment_name) { 'simple' }

  with_reset_sandbox_before_each

  describe 'static drain' do
    before do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['instance_groups'][0]['instances'] = 1

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      manifest_hash['instance_groups'][0]['persistent_disk'] = 100
      manifest_hash['instance_groups'].first['jobs'].first['properties'] ||= {}
      manifest_hash['instance_groups'].first['jobs'].first['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    it 'runs the drain script on a job if drain script is present' do
      drain_log = director.instance('foobar', '0').read_file('drain-test.log')
      expect(drain_log).to eq("job_shutdown hash_unchanged\n1\n")
    end

    it 'sets BOSH_JOB_STATE and BOSH_JOB_NEXT_STATE env vars with changed values' do
      drain_log = director.instance('foobar', '0').read_file('drain-job-state.log')
      expect(drain_log).to include('BOSH_JOB_STATE={"persistent_disk":0}')
      expect(drain_log).to include('BOSH_JOB_NEXT_STATE={"persistent_disk":100}')
    end
  end

  describe 'dynamic drain' do
    before do
      cloud_config_hash = Bosh::Spec::NewDeployments.simple_cloud_config

      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['releases'].first['version'] = 'latest'
      manifest_hash['instance_groups'][0]['instances'] = 1
      manifest_hash['instance_groups'].first['jobs'].first['properties'] ||= {}
      manifest_hash['instance_groups'].first['jobs'].first['properties']['drain_type'] = 'dynamic'

      deploy_from_scratch(cloud_config_hash: cloud_config_hash, manifest_hash: manifest_hash)

      manifest_hash['instance_groups'].first['jobs'].first['properties']['test_property'] = 0
      deploy_simple_manifest(manifest_hash: manifest_hash)
    end

    it 'retries after the appropriate amount of time' do
      drain_log = director.instance('foobar', '0').read_file('drain-test.log')
      drain_times = drain_log.split.map(&:to_i)
      expect(drain_times.size).to eq(3)
      expect(drain_times[1] - drain_times[0]).to be >= 3
      expect(drain_times[2] - drain_times[1]).to be >= 2
    end
  end

  context 'when skip-drain flag is not provided' do
    before do
      deploy_from_scratch(manifest_hash: Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
      director.instances.each do |instance|
        expect(File).not_to exist( instance.file_path('drain-test.log'))
      end
    end

    def drain_file
      director.instance('foobar', '0').file_path('drain-test.log')
    end

    it 'runs drain script for recreate' do
      drain_path_before_recreate = drain_file
      bosh_runner.run('recreate foobar/0', deployment_name: deployment_name)
      expect(File).to exist(drain_path_before_recreate)
    end

    it 'runs drain script for stop' do
      bosh_runner.run('stop foobar/0', deployment_name: deployment_name)
      expect(File).to exist(drain_file)
    end

    it 'runs drain script for restart' do
      bosh_runner.run('restart foobar/0', deployment_name: deployment_name)
      expect(File).to exist(drain_file)
    end

    it 'runs drain scripts for change state of the deployment' do
      bosh_runner.run('stop', deployment_name: deployment_name)
      director.instances.each do |instance|
        expect(File).to exist( instance.file_path('drain-test.log'))
      end
    end

    it 'runs drain scripts for change state of the job' do
      bosh_runner.run('restart foobar', deployment_name: deployment_name)
      director.instances.each do |instance|
        expect(File).to exist( instance.file_path('drain-test.log'))
      end
    end
  end

  context 'when skip-drain flag is provided' do
    let(:manifest_with_drain) do
      manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
      manifest_hash['instance_groups'][0]['instances'] = 1
      manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'test_property' => 'drained' }
      manifest_hash
    end

    before do
      deploy_from_scratch(manifest_hash: manifest_with_drain, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
    end

    def drain_file
      director.instance('foobar', '0').file_path('drain-test.log')
    end

    it 'does not run drain script for recreate' do
      drain_path_before_recreate = drain_file
      bosh_runner.run('recreate foobar/0 --skip-drain', deployment_name: deployment_name)
      expect(File).not_to exist(drain_path_before_recreate)
    end

    it 'does not run drain script for stop' do
      bosh_runner.run('stop foobar/0 --skip-drain', deployment_name: deployment_name)
      expect(File).not_to exist(drain_file)
    end

    it 'does not run drain script for restart' do
      bosh_runner.run('restart foobar/0 --skip-drain', deployment_name: deployment_name)
      expect(File).not_to exist(drain_file)
    end

    context 'with multiple deployment instance groups' do
      let(:manifest_with_drain) do
        manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
        manifest_hash['instance_groups'][0]['instances'] = 1
        manifest_hash['instance_groups'].first['jobs'].first['properties'] = { 'test_property' => 'drained' }
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group(name: 'second', instances: 1)
        manifest_hash['instance_groups'] << Bosh::Spec::NewDeployments.simple_instance_group(name: 'third', instances: 1)
        manifest_hash
      end

      it 'skips drain for specified instance_groups' do
        foobar_drain_file = director.instance('foobar', '0').file_path('drain-test.log')
        second_drain_file = director.instance('second', '0').file_path('drain-test.log')
        third_drain_file = director.instance('third', '0').file_path('drain-test.log')

        deploy_simple_manifest(manifest_hash: manifest_with_drain, recreate: true, skip_drain: ['second', 'third'])
        expect(File).not_to exist(second_drain_file)
        expect(File).not_to exist(third_drain_file)
        expect(File.read(foobar_drain_file)).to include('drained')
      end

      it 'skips drain for all instance_groups' do
        foobar_drain_file = director.instance('foobar', '0').file_path('drain-test.log')
        second_drain_file = director.instance('second', '0').file_path('drain-test.log')

        deploy_simple_manifest(manifest_hash: manifest_with_drain, recreate: true, skip_drain: true)
        expect(File).not_to exist(foobar_drain_file)
        expect(File).not_to exist(second_drain_file)
      end

      it 'does not run drain scripts for change state of the specified job' do
        bosh_runner.run('stop --skip-drain foobar', deployment_name: deployment_name)
        foobar_drain_file = director.instance('foobar', '0').file_path('drain-test.log')
        expect(File).not_to exist(foobar_drain_file)
      end

      it 'does not run drain scripts for change state of the deployment' do
        bosh_runner.run('stop --skip-drain', deployment_name: deployment_name)
        director.instances.each do |instance|
          expect(File).not_to exist( instance.file_path('drain-test.log'))
        end
      end
    end
  end

  context 'with one deployment instance group having colocated jobs, some of which have drain scripts' do
    let(:manifest_with_colocated_drainable_release_jobs) do
      Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell.merge(
          'instance_groups' => [
              Bosh::Spec::NewDeployments.instance_group_with_many_jobs(
                  name: 'colocated',
                  jobs: [
                      {'name' => 'job_1_with_pre_start_script', 'release' => 'bosh-release'},
                      {'name' => 'foobar', 'release' => 'bosh-release'},
                      {'name' => 'has_drain_script', 'release' => 'bosh-release'},
                  ],
                  instances: 1,
              )
          ],
          'properties' => {
              'test_property' => 'multi-drain',
              'drain_type' => 'static',
          }
      )
    end

    it 'runs drain for jobs that have drain script' do
      deploy_from_scratch(manifest_hash: manifest_with_colocated_drainable_release_jobs, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)

      foobar_drain_log = director.instance('colocated', '0').file_path('drain-test.log')
      second_drain_log = director.instance('colocated', '0').file_path('has_drain_script_drain.log')

      deploy_simple_manifest(manifest_hash: manifest_with_colocated_drainable_release_jobs, recreate: true)

      expect(File).to exist(foobar_drain_log)
      expect(File.read(foobar_drain_log)).to include('multi-drain')

      expect(File).to exist(second_drain_log)
      expect(File.read(second_drain_log)).to include('multi-drain')
    end
  end
end
