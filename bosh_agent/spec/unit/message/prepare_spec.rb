require 'spec_helper'
require 'bosh_agent/message/prepare'
require 'fakefs/spec_helpers'

module Bosh::Agent::Message
  describe Prepare do
    include FakeFS::SpecHelpers

    let(:dummy_platform) { instance_double('Bosh::Agent::Platform::Linux::Adapter', update_logging: nil) }
    let(:prepare_spec) { { prepare: 'doit' } }

    subject(:prepare_message) { Prepare.new([prepare_spec]) }

    before do
      Bosh::Agent::Config.state = Bosh::Agent::State.new('state_file')

      Bosh::Agent::Config.stub(platform: dummy_platform)
    end

    context 'when an empty list is passed to the initializer' do
      it 'raises with argument error' do
        expect { Prepare.new([]) }.to raise_error(ArgumentError, 'not enough arguments')
      end
    end

    context 'when non hash is passed as prepare data to initializer' do
      it 'raises with helpful error' do
        expect { Prepare.new(['foo']) }.to raise_error(ArgumentError, 'invalid spec, Hash expected, String given')
      end
    end

    describe '#prepare' do
      it 'creates folders for bosh, jobs, packages, and monit' do
        %w(bosh jobs packages monit).each do |directory|
          File.exists?(File.join(base_dir, directory)).should be(false)
        end

        prepare_message.prepare

        %w(bosh jobs packages monit).each do |directory|
          File.exists?(File.join(base_dir, directory)).should be(true)
        end
      end

      context 'prepare spec is configured' do
        let(:prepare_spec) { { 'fake' => 'prepare_spec' } }
        let(:job) { double('job') }
        let(:package) { double('package') }
        let(:agent_state) { double('agent state', to_hash: {'fake' => 'old_spec'}, write: nil) }
        let(:old_plan) { double('old plan') }
        let(:new_plan) { double('new plan', configured?: true, has_jobs?: true, has_packages?: true) }

        before do
          Bosh::Agent::Config.stub(:state).and_return(agent_state)
          Bosh::Agent::ApplyPlan::Plan.stub(:new).and_return(old_plan)
          Bosh::Agent::ApplyPlan::Plan.stub(:new).with(prepare_spec).and_return(new_plan)
        end

        it 'installs jobs and packages for prepare spec' do
          new_plan.should_receive(:install_jobs)
          new_plan.should_receive(:install_packages)

          prepare_message.prepare
        end

        it 'rescues exceptions and raises a MessageHandlerError' do
          expect { prepare_message.prepare }.to raise_error(Bosh::Agent::MessageHandlerError)
        end

        it 'persists the prepared spec to the agent state file' do
          new_plan.stub(:install_jobs)
          new_plan.stub(:install_packages)
          agent_state.should_receive(:write).with({ 'fake' => 'old_spec', 'prepared_spec' => { 'fake' => 'prepare_spec' } })

          prepare_message.prepare
        end
      end

      context 'prepare spec is not configured' do
        let(:prepare_spec) { { 'fake' => 'prepare_spec' } }
        let(:job) { double('job') }
        let(:package) { double('package') }
        let(:old_plan) { double('old plan') }
        let(:new_plan) { double('new plan', configured?: false, has_jobs?: true, has_packages?: true) }

        before do
          Bosh::Agent::ApplyPlan::Plan.stub(:new).and_return(old_plan)
          Bosh::Agent::ApplyPlan::Plan.stub(:new).with(prepare_spec).and_return(new_plan)
        end

        it 'does not install jobs or packages' do
          new_plan.should_not_receive(:install_jobs)
          new_plan.should_not_receive(:install_packages)

          prepare_message.prepare
        end
      end
    end
  end
end
