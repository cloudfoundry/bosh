require File.expand_path('../../spec/shared/spec_helper', __dir__)

require 'async/rspec'
require 'async/io'
require 'tempfile'
require 'bosh/monitor'
require 'webmock/rspec'
require 'timecop'

Dir.glob(File.expand_path('support/**/*.rb', __dir__)).each { |f| require(f) }

def asset_path(filename)
  File.expand_path(File.join(File.dirname(__FILE__), 'assets', filename))
end

def sample_config
  asset_path('sample_config.yml')
end

def default_config
  {
    'logfile' => STDOUT,
    'loglevel' => 'off',
    'director' => {},
  }
end

def alert_payload(attrs = {})
  {
    id: 'foo',
    severity: 2,
    title: 'Alert',
    created_at: Time.now,
  }.merge(attrs)
end

def heartbeat_payload(attrs = {})
  {
    id: 'foo',
    timestamp: Time.now,
  }.merge(attrs)
end

def make_alert(attrs = {})
  defaults = {
    'id' => 1,
    'severity' => 2,
    'title' => 'Test Alert',
    'summary' => 'Everything is down',
    'source' => 'mysql_node/instance_id_abc',
    'deployment' => 'deployment',
    'job' => 'job',
    'instance_id' => 'instance_id',
    'created_at' => Time.now.to_i,
  }
  Bhm::Events::Alert.new(defaults.merge(attrs))
end

def make_heartbeat(attrs = {})
  defaults = {
    id: 1,
    timestamp: Time.now.to_i,
    deployment: 'oleg-cloud',
    agent_id: 'deadbeef',
    instance_id: 'instance_id_abc',
    job: 'mysql_node',
    index: 0,
    job_state: 'running',
    vitals: {
      'load' => [0.2, 0.3, 0.6],
      'cpu' => { 'user' => 22.3, 'sys' => 23.4, 'wait' => 33.22 },
      'mem' => { 'percent' => 32.2, 'kb' => 512031 },
      'swap' => { 'percent' => 32.6, 'kb' => 231312 },
      'disk' => {
        'system' => { 'percent' => 74, 'inode_percent' => 68 },
        'ephemeral' => { 'percent' => 33, 'inode_percent' => 74 },
        'persistent' => { 'percent' => 97, 'inode_percent' => 10 },
      },
    },
    teams: %w[ateam bteam],
  }
  Bhm::Events::Heartbeat.new(defaults.merge(attrs))
end

def find_free_tcp_port
  server = TCPServer.new('127.0.0.1', 0)
  server.addr[1]
ensure
  server.close
end

RSpec.configure do |c|
  c.color = true

  c.around do |example|
    Bhm.config = default_config

    example.call
  end
end
