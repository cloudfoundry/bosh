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

  describe "/unhealthy_agents" do
    let(:unhealthy_agents) do
      {
        "first_deployment" => 3,
        "second_deployment" => 1,
      }
    end
    before do
      allow(Bosh::Monitor.instance_manager).to receive(:unhealthy_agents).and_return(unhealthy_agents)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it "renders the unhealthy agents" do
      get "/unhealthy_agents"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(unhealthy_agents))
    end

    context "When director initial deployment sync has not completed" do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it "returns 503 when /unhealthy_agents is requested" do
        get "/unhealthy_agents"
        expect(last_response.status).to eq(503)
      end
    end
  end

  describe "/total_available_agents" do
    let(:available_agents) do
      {
        "first_deployment" => 5,
        "second_deployment" => 2,
      }
    end

    before do
      allow(Bosh::Monitor.instance_manager).to receive(:total_available_agents).and_return(available_agents)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it "renders the total available agents (all agents, no criteria)" do
      get "/total_available_agents"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(available_agents))
    end

    context "When director initial deployment sync has not completed" do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it "returns 503 when /total_available_agents is requested" do
        get "/total_available_agents"
        expect(last_response.status).to eq(503)
      end
    end
  end

  describe "/failing_instances" do
    let(:failing_instances) do
      {
        "first_deployment" => 2,
        "second_deployment" => 0,
      }
    end

    before do
      allow(Bosh::Monitor.instance_manager).to receive(:failing_instances).and_return(failing_instances)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it "renders failing instances" do
      get "/failing_instances"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(failing_instances))
    end

    context "When director initial deployment sync has not completed" do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it "returns 503 when /failing_instances is requested" do
        get "/failing_instances"
        expect(last_response.status).to eq(503)
      end
    end
  end

  describe "/stopped_instances" do
    let(:stopped_instances) do
      {
        "first_deployment" => 1,
        "second_deployment" => 0,
      }
    end

    before do
      allow(Bosh::Monitor.instance_manager).to receive(:stopped_instances).and_return(stopped_instances)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it "renders stopped instances" do
      get "/stopped_instances"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(stopped_instances))
    end

    context "When director initial deployment sync has not completed" do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it "returns 503 when /stopped_instances is requested" do
        get "/stopped_instances"
        expect(last_response.status).to eq(503)
      end
    end
  end

  describe "/unknown_instances" do
    let(:unknown_instances) do
      {
        "first_deployment" => 0,
        "second_deployment" => 1,
      }
    end

    before do
      allow(Bosh::Monitor.instance_manager).to receive(:unknown_instances).and_return(unknown_instances)
      allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(true)
    end

    it "renders unknown instances" do
      get "/unknown_instances"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq(JSON.generate(unknown_instances))
    end

    context "When director initial deployment sync has not completed" do
      before do
        allow(Bosh::Monitor.instance_manager).to receive(:director_initial_deployment_sync_done).and_return(false)
      end

      it "returns 503 when /unknown_instances is requested" do
        get "/unknown_instances"
        expect(last_response.status).to eq(503)
      end
    end
  end
end
