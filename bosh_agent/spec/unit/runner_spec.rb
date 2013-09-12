require 'spec_helper'

module Bosh::Agent
  describe Runner do
    describe '.run' do
      let(:runner) do
        instance_double('Bosh::Agent::Runner', start: nil)
      end

      before do
        runner.should_receive(:start)
        Runner.stub(:new).and_return(runner)
      end

      it 'sets up the global config with the options passed' do
        config = class_double('Bosh::Agent::Config').as_stubbed_const
        config.should_receive(:setup).with(fake: 'options')

        Bosh::Agent::Runner.run(fake: 'options')
      end

      it 'creates a new runner and starts it' do

        Bosh::Agent::Runner.run(fake: 'options')
      end
    end

    describe '#start' do
      let(:logger) do
        instance_double('Logger', info: nil)
      end

      let(:bootstrap) do
        instance_double('Bosh::Agent::Bootstrap', configure: nil)
      end

      let(:nats_url) do
        'nats://user:pass@host:port'
      end

      subject(:runner) do
        Runner.new
      end

      before do
        Bosh::Agent::Bootstrap.stub(new: bootstrap)
        @nat_handler = class_double('Bosh::Agent::Handler', start: nil).as_stubbed_const
        @config = class_double('Bosh::Agent::Config',
                               mbus: nats_url,
                               logger: logger,
                               configure: true).as_stubbed_const
        @monit = class_double('Bosh::Agent::Monit', enable: nil,
                                                    start: nil,
                                                    start_services: nil).as_stubbed_const
      end

      it 'bootstraps the agent' do
        bootstrap.should_receive(:configure)

        runner.start
      end

      it 'starts monit' do
        @monit.should_receive(:enable)
        @monit.should_receive(:start)
        @monit.should_receive(:start_services)

        runner.start
      end

      it 'starts a nats handler by default' do
        @nat_handler.should_receive(:start)

        runner.start
      end

      context 'when the mbus url begins with https' do
        let(:nats_url) do
          'https://user:pass@host:port'
        end

        before do
          runner.stub(:require)
          @http_handler = class_double('Bosh::Agent::HTTPHandler', start: nil).as_stubbed_const
        end

        it 'lazily requires an http handler' do
          runner.should_receive(:require).with('bosh_agent/http_handler')

          runner.start
        end

        it 'starts an http handler' do
          @http_handler.should_receive(:start)

          runner.start
        end
      end
    end
  end
end
