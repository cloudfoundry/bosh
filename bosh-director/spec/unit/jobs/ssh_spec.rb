require 'spec_helper'
require 'fakefs/spec_helpers'

module Bosh::Director
  describe Jobs::Ssh do
    include FakeFS::SpecHelpers
    subject(:job) { described_class.new(deployment.id, {'target' => target, 'command' => 'fake-command', 'params' => {}, :blobstore => {}}) }
    let(:agent) { double(AgentClient) }
    let(:config) { double(Config) }
    let(:instance_manager) { Api::InstanceManager.new }
    let(:deployment) { Models::Deployment.make }
    let(:result_file) { TaskResultFile.new(result_file_path) }
    let(:target) { {'job' => 'fake-job', 'indexes' => [1]} }
    let(:result_file_path) { 'ssh-spec' }
    describe 'Resque job class expectations' do
      let(:job_type) { :ssh }
      it_behaves_like 'a Resque job'
    end

    before do
      Models::Instance.make(job: 'fake-job', index: 1, deployment: deployment, uuid: 'fake-uuid-1')
      Models::Instance.make(job: 'fake-job', index: 2, deployment: deployment, uuid: 'fake-uuid-2')
      allow(Api::InstanceManager).to receive(:new).and_return(instance_manager)
      allow(instance_manager).to receive(:agent_client_for).and_return(agent)
      allow(agent).to receive(:ssh).and_return({})
      Config.default_ssh_options = {'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}
      Config.result = result_file
    end

    def parsed_result_file
      Yajl.load(File.read(result_file_path))
    end

    after { FileUtils.rm_rf(result_file_path) }

    it 'returns default_ssh_options if they exist' do
      job.perform

      expect(parsed_result_file).to eq([{'index' => 1, 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}])
    end

    context 'when instance id was passed in' do
      let(:target) { {'job' => 'fake-job', 'ids' => ['fake-uuid-1']} }

      context 'when id is instance uuid' do
        it 'finds instance by its id and generates response with id' do
          job.perform
          expect(parsed_result_file).to eq([{'id' => 'fake-uuid-1', 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}])
        end
      end

      context 'when id is instance index' do
        let(:target) { {'job' => 'fake-job', 'ids' => [2]} }

        it 'finds instance by its index and generates response with id' do
          job.perform
          expect(parsed_result_file).to eq([{'id' => 'fake-uuid-2', 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}])
        end
      end
    end
  end
end
