require 'spec_helper'

describe Bhm::Runner do
  subject(:runner) { Bhm::Runner.new(sample_config) }

  let!(:thin_server_class) { class_double(Thin::Server).as_stubbed_const }

  it 'reads provided configuration file and sets Bhm singletons' do
    subject

    Bhm.logger.should be_kind_of(Logging::Logger)
    Bhm.director.should be_kind_of(Bhm::Director)

    Bhm.intervals.poll_director.should be_kind_of Integer
    Bhm.intervals.log_stats.should be_kind_of Integer
    Bhm.intervals.agent_timeout.should be_kind_of Integer

    Bhm.mbus.endpoint.should == 'nats://127.0.0.1:4222'
    Bhm.mbus.user.should be_nil
    Bhm.mbus.password.should be_nil

    Bhm.plugins.size.should == 8
  end

  describe 'stop' do
    context 'when there is an http server' do
      before do
        allow(thin_server_class).to receive(:new).with('0.0.0.0', Bhm.http_port, signals: false).and_return(http_server)
      end
      let(:http_server) { double(Thin::Server) }
      before { allow(http_server).to receive(:start!) }

      before { runner.start_http_server }

      it 'stops the http server' do
        expect(http_server).to receive(:stop!)
        runner.stop
      end
    end

    context 'when there is no http server' do
      it 'does not fail' do
        expect { runner.stop }.not_to raise_error
      end
    end
  end
end
