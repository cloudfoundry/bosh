require 'spec_helper'
require 'rack/test'

describe Bosh::Monitor::ApiController do
  include Rack::Test::Methods

  def app
    Bosh::Monitor::ApiController.new
  end

  let(:config) { class_double(Bosh::Monitor)  }
  before { stub_const("Bhm", config) }
  before { allow(EM).to receive(:add_periodic_timer) { } }

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
      let(:last_pulse) { Bosh::Monitor::ApiController::PULSE_TIMEOUT + 1 }

      before { now += last_pulse }

      it 'returns 500' do
        get '/healthz'
        expect(last_response.status).to eq(500)
        expect(last_response.body).to eq("Last pulse was #{last_pulse} seconds ago")
      end

      it 'can recover from poor health' do
        get '/healthz'
        expect(last_response.status).to eq(500)
        expect(last_response.body).to eq("Last pulse was #{last_pulse} seconds ago")
        run_em_timers

        get '/healthz'
        expect(last_response.status).to eq(200)
      end
    end
  end
end
