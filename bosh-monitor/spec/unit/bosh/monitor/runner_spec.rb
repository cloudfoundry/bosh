require 'spec_helper'

describe Bhm::Runner do
  subject(:runner) { Bhm::Runner.new(sample_config) }

  let!(:thin_server_class) { class_double(Thin::Server).as_stubbed_const }

  it 'reads provided configuration file and sets Bhm singletons' do
    subject

    expect(Bhm.logger).to be_kind_of(Logging::Logger)
    expect(Bhm.director).to be_kind_of(Bhm::Director)

    expect(Bhm.intervals.poll_director).to be_kind_of Integer
    expect(Bhm.intervals.log_stats).to be_kind_of Integer
    expect(Bhm.intervals.agent_timeout).to be_kind_of Integer

    expect(Bhm.mbus.endpoint).to eq('nats://127.0.0.1:4222')
    expect(Bhm.mbus.user).to be_nil
    expect(Bhm.mbus.password).to be_nil

    expect(Bhm.plugins.size).to eq(8)
  end

  describe 'stop' do
    context 'when there is an http server' do
      before do
        allow(thin_server_class).to receive(:new).with('127.0.0.1', Bhm.http_port, signals: false).and_return(http_server)
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

  describe "start_http_server" do
    it 'starts a Thin::Server with the correct parameters' do
      http_server = double(Thin::Server)
      expect(thin_server_class).to receive(:new).with('127.0.0.1', Bhm.http_port, signals: false).and_return(http_server)
      expect(http_server).to receive(:start!)
      runner.start_http_server
    end
  end
end
