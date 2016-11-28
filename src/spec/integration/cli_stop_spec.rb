require 'spec_helper'

describe 'stop command', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'] << {
      'name' => 'another-job',
      'template' => 'foobar',
      'resource_pool' => 'a',
      'instances' => 1,
      'networks' => [{'name' => 'a'}],
    }
    manifest_hash
  end

  context 'with a job name' do
    before do
      deploy_from_scratch(manifest_hash: manifest_hash)
    end

    context 'with an index or id' do
      it 'stops the indexed job' do
        expect {
          output = bosh_runner.run('stop foobar 0')
          expect(output).to include('foobar/0 stopped, VM(s) still running')
        }.to change { vm_states }
          .from({
              'another-job/0' => 'running',
              'foobar/0' => 'running',
              'foobar/1' => 'running',
              'foobar/2' => 'running'
            })
          .to({
              'another-job/0' => 'running',
              'foobar/0' => 'stopped',
              'foobar/1' => 'running',
              'foobar/2' => 'running'
          })

        vm_before_with_index_1 = director.vms.find{ |vm| vm.index == '1'}
        instance_uuid = vm_before_with_index_1.instance_uuid

        expect {
          output = bosh_runner.run("stop foobar #{instance_uuid}")
          expect(output).to include("foobar/#{instance_uuid} stopped, VM(s) still running")
        }.to change { vm_states }
          .from({
              'another-job/0' => 'running',
              'foobar/0' => 'stopped',
              'foobar/1' => 'running',
              'foobar/2' => 'running'
            })
          .to({
              'another-job/0' => 'running',
              'foobar/0' => 'stopped',
              'foobar/1' => 'stopped',
              'foobar/2' => 'running'
          })

        output = bosh_runner.run('events')
        parser = Support::TableHelpers::Parser.new(scrub_event_time(scrub_random_cids(scrub_random_ids(output))))
        expect(parser.data).to include(
          {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => 'before: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]},'},
          {'ID' => '', 'Time' => '', 'User' => '', 'Action' => '', 'Object type' => '', 'Task' => '', 'Object ID' => '', 'Dep' => '', 'Inst' => '', 'Context' => 'after: {"releases"=>["bosh-release/0+dev.1"], "stemcells"=>["ubuntu-stemcell/1"]}'},
          {'ID' => /[0-9]{1,3} <- [0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'stop', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
          {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'stop', 'Object type' => 'instance', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Dep' => 'simple', 'Inst' => 'foobar/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', 'Context' => '-'},
          {'ID' => /[0-9]{1,3}/, 'Time' => 'xxx xxx xx xx:xx:xx UTC xxxx', 'User' => 'test', 'Action' => 'update', 'Object type' => 'deployment', 'Task' => /[0-9]{1,3}/, 'Object ID' => 'simple', 'Dep' => 'simple', 'Inst' => '-', 'Context' => '-'}
        )
      end
    end

    context 'without an index or id' do
      it 'stops all instances of the job' do
        expect {
          output = bosh_runner.run('stop foobar')
          expect(output).to include('foobar/* stopped, VM(s) still running')
        }.to change { vm_states }
          .from({
              'another-job/0' => 'running',
              'foobar/0' => 'running',
              'foobar/1' => 'running',
              'foobar/2' => 'running'
          })
          .to({
              'another-job/0' => 'running',
              'foobar/0' => 'stopped',
              'foobar/1' => 'stopped',
              'foobar/2' => 'stopped'
          })
      end
    end

    context 'given the --hard flag' do
      it 'deletes the VM(s)' do
        expect {
          output = bosh_runner.run('stop foobar 0 --hard')
          expect(output).to include('foobar/0 detached, VM(s) deleted')
        }.to change { director.vms.count }.by(-1)
      end
    end
  end

  context 'without a job name' do
    before do
      deploy_from_scratch(manifest_hash: manifest_hash)
    end

    it 'stops all jobs in the deployment' do
      expect {
        output = bosh_runner.run('stop')
        expect(output).to include('all jobs stopped, VM(s) still running')
      }.to change { vm_states }
        .from({
            'another-job/0' => 'running',
            'foobar/0' => 'running',
            'foobar/1' => 'running',
            'foobar/2' => 'running'
          })
        .to({
            'another-job/0' => 'stopped',
            'foobar/0' => 'stopped',
            'foobar/1' => 'stopped',
            'foobar/2' => 'stopped'
        })
    end
  end

  describe 'hard-stopping a job with persistent disk, followed by a re-deploy' do
    before do
      manifest_hash['jobs'].first['persistent_disk'] = 1024
      deploy_from_scratch(manifest_hash: manifest_hash)
    end

    it 'is successful (regression: #108398600) ' do
      bosh_runner.run('stop foobar --hard')
      expect(vm_states).to eq({'another-job/0' => 'running'})
      expect {
        deploy_from_scratch(manifest_hash: manifest_hash)
      }.to_not raise_error
      expect(vm_states).to eq({'another-job/0' => 'running'})
    end
  end

  def vm_states
    director.vms.inject({}) do |result, vm|
      result["#{vm.job_name}/#{vm.index}"] = vm.last_known_state
      result
    end
  end
end
