require 'spec_helper'

describe Bosh::WardenCloud::Helpers do
  include Bosh::WardenCloud::Helpers

  context 'uuid' do
    it 'can generate the correct uuid' do
      uuid('disk').should start_with 'disk'
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
      [:connect, :disconnect].each do |op|
        Warden::Client.any_instance.stub(op) do
          # no-op
        end
      end
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::RunRequest
            req.script.should == "cat #{agent_settings_file}"
            res.stdout = %{{"vm":{"name":"vm-name","id":"vm-id"},"agent_id":"vm-agent"}}
          else
            raise "#{req} not supported"
        end
        res
      end
      @agent_properties = { 'ntp' => 'test' }
    end

    it 'generate agent env from agent_properties' do
      env = generate_agent_env('vm-id', 'agent-id', {})
      env['vm']['name'].should == 'vm-id'
      env['vm']['id'].should == 'vm-id'
      env['agent_id'].should == 'agent-id'
      env['ntp'].should == 'test'
    end

    it 'invoke warden to cat agent_settings_file' do
      env = get_agent_env('fake_handle')
      env['vm']['name'].should == 'vm-name'
      env['vm']['id'].should == 'vm-id'
      env['agent_id'].should == 'vm-agent'
    end
  end

  context 'set agent env' do
    before :each do
      [:connect, :disconnect].each do |op|
        Warden::Client.any_instance.stub(op) do
          # no-op
        end
      end
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::RunRequest
            req.script.should == "mv /tmp/100 #{agent_settings_file}"
          when Warden::Protocol::CopyInRequest
            req.dst_path.should == '/tmp/100'
          else
            raise "#{req} not supported"
        end
        res
      end
    end

    it 'generate a random file in tmp and mv to agent_setting_file' do
      Kernel.stub!(:rand).and_return(100)
      set_agent_env('fake_handle', {})
    end
  end

  context 'start agent' do
    before :each do
      [:connect, :disconnect].each do |op|
        Warden::Client.any_instance.stub(op) do
          # no-op
        end
      end
      Warden::Client.any_instance.stub(:call) do |req|
        res = req.create_response
        case req
          when Warden::Protocol::SpawnRequest
            req.script.should == '/usr/sbin/runsvdir-start'
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
