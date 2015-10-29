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
    let(:result_file) { instance_double(TaskResultFile) }
    let(:target) { {'job' => 'fake-job', 'indexes' => 5} }
    describe 'Resque job class expectations' do
      let(:job_type) { :ssh }
      it_behaves_like 'a Resque job'
    end

    before do
      Models::Instance.make(job: 'fake-job', index: 5, deployment: deployment, uuid: 'fake-uuid')
      allow(Api::InstanceManager).to receive(:new).and_return(instance_manager)
      allow(instance_manager).to receive(:agent_client_for).and_return(agent)
      allow(agent).to receive(:ssh).and_return({})
      Config.default_ssh_options = {'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}
      allow(TaskResultFile).to receive(:new).and_return(result_file)
      allow(result_file).to receive(:write).with("\n")
      Config.result = result_file
    end

    it 'returns default_ssh_options if they exist' do
      expect(result_file).to receive(:write).with(Yajl::Encoder.encode([{'index' => 5, 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}]))

      job.perform
    end

    context 'when instance id was passed in' do
      let(:target) { {'job' => 'fake-job', 'id' => 'fake-uuid'} }

      it 'finds instance by its id and generates response with id' do
        expect(result_file).to receive(:write).with(Yajl::Encoder.encode([{'id' => 'fake-uuid', 'gateway_host' => 'fake-host', 'gateway_user' => 'vcap'}]))

        job.perform
      end
    end
  end
end
