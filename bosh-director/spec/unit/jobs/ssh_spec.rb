require 'spec_helper'

module Bosh::Director
  describe Jobs::Ssh do
    include FakeFS::SpecHelpers
    subject(:job) { described_class.new('FAKE_DEPLOYMENT_ID', {"target" => {}, "command" => "fake-command", "params" => {}, :blobstore => {}}) }
    let (:agent) { instance_double (AgentClient)}
    let (:config) {double(Config)}
    let (:instance_manager) { instance_double (Api::InstanceManager)}
    let (:instance) { instance_double(Models::Instance)}
    let (:result_file) { instance_double(TaskResultFile) }
    describe 'Resque job class expectations' do
      let(:job_type) { :ssh }
      it_behaves_like 'a Resque job'
    end

    it 'returns default_ssh_options if they exist' do
      allow(Api::InstanceManager).to receive(:new).and_return(instance_manager)
      allow(instance_manager).to receive(:filter_by).and_return([instance])
      allow(instance).to receive(:index).and_return(0)
      allow(instance).to receive(:job).and_return("a job")
      allow(instance_manager).to receive(:agent_client_for).and_return(agent)
      allow(agent).to receive(:method_missing).and_return({})
      Config.default_ssh_options = {"gateway_host" => "fake-host", "gateway_user" => "vcap"}
      allow(TaskResultFile).to receive(:new).and_return(result_file)
      allow(result_file).to receive(:write).with("\n");

      expect(result_file).to receive(:write).with(Yajl::Encoder.encode([{"index" => 0, "gateway_host" => "fake-host", "gateway_user" => "vcap"}]))
      Config.result = result_file

      job.perform

    end
  end
end