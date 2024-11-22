require 'spec_helper'

describe Bosh::Monitor::ApiController do
  include Rack::Test::Methods
  include_context Async::RSpec::Reactor

  let(:heartbeat_interval) { 0.01 }

  def app
    Bosh::Monitor::ApiController.new(heartbeat_interval)
  end

  describe '/healthz' do
    now = 0
    before do
      allow(Time).to receive(:now) { now }

      current_session # get the App started
    end

    it 'should start out healthy' do
      get '/healthz'
      expect(last_response.status).to eq(200)
    end

    context 'when the event loop processes the heartbeat task within a time limit' do
      it 'returns 200 OK' do
        get '/healthz'
        expect(last_response.status).to eq(200)
      end
    end

    context 'when the event loop has been occupied for a while' do
      let(:last_pulse) { Bosh::Monitor::ApiController::PULSE_TIMEOUT + heartbeat_interval }

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

        # Allow async task to record new heartbeat
        sleep heartbeat_interval

        get '/healthz'
        expect(last_response.status).to eq(200)
      end
    end
  end

  describe '/unresponsive_agents' do
    let(:unresponsive_agents) do
      {
        'first_deployment' => 2,
        'second_deployment' => 0,
      }
    end
    before do
      allow(Bosh::Monitor.instance_manager).to receive(:unresponsive_agents).and_return(unresponsive_agents)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it 'renders the unresponsive agents' do
      get '/unresponsive_agents'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(unresponsive_agents))
    end

    context 'When director initial deployment sync has not completed' do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it 'returns 503 when /unresponsive_agents is requested' do
        get '/unresponsive_agents'
        expect(last_response.status).to eq(503)
      end

    end
  end
end
