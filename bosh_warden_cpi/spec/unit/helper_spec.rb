require 'spec_helper'

describe Bosh::WardenCloud::Helpers do
  include Bosh::WardenCloud::Helpers

  before :each do
    @warden_client = double('Warden::Client')
    allow(Warden::Client).to receive(:new).and_return(@warden_client)

    allow(@warden_client).to receive(:connect) {}
    allow(@warden_client).to receive(:disconnect) {}
  end

  context 'uuid' do
    it 'can generate the correct uuid' do
      expect(uuid('disk')).to start_with 'disk'
    end
  end

  context 'sudo/sh' do
    it 'run sudo cmd with sudo' do
      mock_sh('fake', true)
      sudo('fake')
    end

    it 'run sh cmd with sh' do
      mock_sh('fake')
      sh('fake')
    end
  end

  context 'generate and get agent env' do
    before :each do
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::RunRequest
            expect(req.script).to eq("cat #{agent_settings_file}")
            res.stdout = %{{"vm":{"name":"vm-name","id":"vm-id"},"agent_id":"vm-agent"}}
          else
            raise "#{req} not supported"
        end
        res
      end
      @agent_properties = { 'ntp' => 'test' }
    end

    it 'generate agent env from agent_properties' do
      env = generate_agent_env('vm-id', 'agent-id', {}, { 'password' => 'abc' })
      expect(env['vm']['name']).to eq('vm-id')
      expect(env['vm']['id']).to eq('vm-id')
      expect(env['agent_id']).to eq('agent-id')
      expect(env['ntp']).to eq('test')
      expect(env['env']['password']).to eq('abc')
    end

    it 'invoke warden to cat agent_settings_file' do
      env = get_agent_env('fake_handle')
      expect(env['vm']['name']).to eq('vm-name')
      expect(env['vm']['id']).to eq('vm-id')
      expect(env['agent_id']).to eq('vm-agent')
    end
  end

  context 'set agent env' do
    before :each do
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::RunRequest
            expect(req.script).to eq("mv /tmp/100 #{agent_settings_file}")
          when Warden::Protocol::CopyInRequest
            expect(req.dst_path).to eq('/tmp/100')
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'generate a random file in tmp and mv to agent_setting_file' do
      allow(Kernel).to receive(:rand).and_return(100)
      set_agent_env('fake_handle', {})
    end
  end

  context 'start agent' do
    before :each do
      allow(@warden_client).to receive(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::SpawnRequest
            expect(req.script).to eq('/usr/sbin/runsvdir-start')
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'runs runsvdir-start when start agent' do
      start_agent('fake_handle')
    end
  end

end
