require 'spec_helper'
require 'rack/test'

describe Bosh::Monitor::ApiController do
  include Rack::Test::Methods

  def app
    Bosh::Monitor::ApiController.new
  end

  let(:config) { class_double(Bosh::Monitor)  }
  let(:varz) { { 'deployments_count' => 1, 'agents_count' => 1 } }
  before { allow(config).to receive(:http_user).and_return('http_user') }
  before { allow(config).to receive(:http_password).and_return('http_password') }
  before { allow(config).to receive(:varz).and_return(varz) }
  before { stub_const("Bhm", config) }
  before { allow(EM).to receive(:add_periodic_timer) { } }

  describe "/varz" do
    context "when using authorized credentials" do
      before { basic_authorize(config.http_user, config.http_password) }

      it 'returns Bhm.varz in JSON format' do
        get '/varz'
        expect(last_response.body).to eq(Yajl::Encoder.encode(varz, :terminator => "\n"))
      end
    end

    context "when using unauthorized credentials" do
      before { basic_authorize('unauthorized', 'user') }

      it 'returns 401' do
        get '/varz'
        expect(last_response.status).to eq(401)
      end
    end
  end

  describe "/healthz" do
    let(:periodic_timers) { [] }
    let(:defers) { [] }
    now = 0
    before do
      allow(EM).to receive(:add_periodic_timer) { |&block| periodic_timers << block }
      allow(EM).to receive(:defer) { |&block| defers << block }
      allow(Time).to receive(:now) { now }

      current_session # get the App started
    end

    def run_em_timers
      periodic_timers.each(&:call)
      defers.each(&:call); defers.clear
    end

    it 'should start out healthy' do
      get '/healthz'
      expect(last_response.status).to eq(200)
    end

    context 'when a thread has become available in the EM thread pool within a time limit' do
      it 'returns 200 OK' do
        now + Bosh::Monitor::ApiController::PULSE_TIMEOUT + 1
        run_em_timers

        get '/healthz'
        expect(last_response.status).to eq(200)
      end
    end

    context 'when the EM thread pool has been occupied for a while' do
      it 'returns 500' do
        now += Bosh::Monitor::ApiController::PULSE_TIMEOUT + 1

        get '/healthz'
        expect(last_response.status).to eq(500)
      end

      it 'can recover from poor health' do
        now += Bosh::Monitor::ApiController::PULSE_TIMEOUT + 1

        get '/healthz'
        expect(last_response.status).to eq(500)

        run_em_timers

        get '/healthz'
        expect(last_response.status).to eq(200)
      end
    end
  end
end
