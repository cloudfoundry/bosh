require File.expand_path('../../../spec/shared_spec_helper', __FILE__)

require 'tempfile'
require 'bosh/monitor'
require 'support/buffered_logger'
require 'support/uaa_helpers'
require 'webmock/rspec'

def spec_asset(filename)
  File.expand_path(File.join(File.dirname(__FILE__), "assets", filename))
end

def sample_config
  spec_asset("sample_config.yml")
end

def default_config
  {
    'logfile' => STDOUT,
    'loglevel' => 'off',
    'director' => {}
  }
end

def alert_payload(attrs = {})
  {
    :id => "foo",
    :severity => 2,
    :title => "Alert",
    :created_at => Time.now
  }.merge(attrs)
end

def heartbeat_payload(attrs = {})
  {
    :id => "foo",
    :timestamp => Time.now
  }.merge(attrs)
end

def make_alert(attrs = {})
  defaults = {
      :id => 1,
      :severity => 2,
      :title => "Test Alert",
      :summary => "Everything is down",
      :source => "mysql_node/0",
      :created_at => Time.now.to_i
  }
  Bhm::Events::Alert.new(defaults.merge(attrs))
end

def make_heartbeat(attrs = {})
  defaults = {
      :id => 1,
      :timestamp => Time.now.to_i,
      :deployment => "oleg-cloud",
      :agent_id => "deadbeef",
      :job => "mysql_node",
      :index => 0,
      :job_state => "running",
      :vitals => {
          "load" => [0.2, 0.3, 0.6],
          "cpu" => { "user" => 22.3, "sys" => 23.4, "wait" => 33.22 },
          "mem" => { "percent" => 32.2, "kb" => 512031 },
          "swap" => { "percent" => 32.6, "kb" => 231312 },
          "disk" => {
              "system" => { "percent" => 74, "inode_percent" =>  68},
              "ephemeral" => { "percent" => 33, "inode_percent" =>  74 },
              "persistent" => { "percent" => 97, "inode_percent" =>  10 },
          }
      }
  }
  Bhm::Events::Heartbeat.new(defaults.merge(attrs))
end

def find_free_tcp_port
  begin
    server = TCPServer.new('127.0.0.1', 0)
    server.addr[1]
  ensure
    server.close
  end
end

RSpec.configure do |c|
  c.color = true

  # Could not use after hook because the tests can start EM in an around block
  # which causes EM.reactor_running? to always return true.
  c.around do |example|
    Bhm::config = default_config

    example.call
    if EM.reactor_running?
      EM.stop

      max_tries = 50
      while max_tries > 0
        break if !EM.reactor_running?
        max_tries -= 1
        sleep(0.1)
      end

      raise 'EM still running, but expected to not.' if EM.reactor_running?
     end
  end
end
