require 'rspec'
require 'yaml'
require 'bosh/template/evaluation_context'
require 'json'
require_relative './template_example_group'

describe 'health_monitor.yml.erb' do
  let(:deployment_manifest_fragment) do
    {
      'properties' => {
        'hm' => {
          'http' => {
            'port' => 8081,
          },
          'director_account' => {
            'user' => 'admin',
            'password' => 'admin_password',
            'client_id' => 'fake_id',
            'client_secret' => 'fake_secret',
          },
          'intervals' => {
            'prune_events' => 60,
            'poll_director' => 61,
            'poll_grace_period' => 62,
            'log_stats' => 63,
            'analyze_agents' => 64,
            'agent_timeout' => 65,
            'rogue_agent_alert' => 66,
            'analyze_instances' => 64,
          },
          'loglevel' => 'INFO',
          'em_threadpool_size' => 20,
          # plugins
          'email_notifications' => false,
          'tsdb_enabled' => false,
          'cloud_watch_enabled' => false,
          'resurrector_enabled' => false,
          'pagerduty_enabled' => false,
          'datadog_enabled' => false,
          'riemann_enabled' => false,
          'graphite_enabled' => false,
          'consul_event_forwarder_enabled' => false,
        },
        'event_nats_enabled' => false,
        'nats' => {
          'address' => '0.0.0.0',
          'port' => 4222,
        },
        'director' => {
          'address' => '0.0.0.0',
          'port' => 25555,
        }
      }
    }
  end

  let(:erb_yaml) { File.read(File.join(File.dirname(__FILE__), '../jobs/health_monitor/templates/health_monitor.yml.erb')) }

  subject(:parsed_yaml) do
    binding = Bosh::Template::EvaluationContext.new(deployment_manifest_fragment, nil).get_binding
    YAML.load(ERB.new(erb_yaml).result(binding))
  end

  context 'given a valid, minimal manifest' do
    it 'renders' do
      expect(parsed_yaml['http']['port']).to eq(8081)
      expect(parsed_yaml['mbus']['endpoint']).to eq('nats://0.0.0.0:4222')
      expect(parsed_yaml['mbus']['server_ca_path']).to eq('/var/vcap/jobs/health_monitor/config/nats_server_ca.pem')
      expect(parsed_yaml['mbus']['client_certificate_path']).to eq('/var/vcap/jobs/health_monitor/config/nats_client_certificate.pem')
      expect(parsed_yaml['mbus']['client_private_key_path']).to eq('/var/vcap/jobs/health_monitor/config/nats_client_private_key')
      expect(parsed_yaml['director']['endpoint']).to eq('https://0.0.0.0:25555')
      expect(parsed_yaml['director']['user']).to eq('admin')
      expect(parsed_yaml['director']['password']).to eq('admin_password')
      expect(parsed_yaml['director']['client_id']).to eq('fake_id')
      expect(parsed_yaml['director']['client_secret']).to eq('fake_secret')
      expect(parsed_yaml['director']['ca_cert']).to be_a(String)
      expect(parsed_yaml['intervals']['prune_events']).to eq(60)
      expect(parsed_yaml['intervals']['poll_director']).to eq(61)
      expect(parsed_yaml['intervals']['poll_grace_period']).to eq(62)
      expect(parsed_yaml['intervals']['log_stats']).to eq(63)
      expect(parsed_yaml['intervals']['analyze_agents']).to eq(64)
      expect(parsed_yaml['intervals']['agent_timeout']).to eq(65)
      expect(parsed_yaml['intervals']['rogue_agent_alert']).to eq(66)
      expect(parsed_yaml['intervals']['analyze_instances']).to eq(64)
      expect(parsed_yaml['logfile']).to be_a(String)
      expect(parsed_yaml['loglevel']).to eq('INFO')
      expect(parsed_yaml['em_threadpool_size']).to eq(20)

      expect(parsed_yaml['plugins'].length).to eq(3)
      expect(parsed_yaml['plugins'].first['name']).to eq('logger')
      expect(parsed_yaml['plugins'].first['events']).to be_a(Array)
      expect(parsed_yaml['plugins'][1]['name']).to eq('event_logger')
      expect(parsed_yaml['plugins'][1]['events']).to be_a(Array)
      expect(parsed_yaml['plugins'][1]['options']['director']).to eq(parsed_yaml['director'])
    end

    context 'plugin is enabled' do
      context 'email' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'email_notifications' => true,
              'email_recipients' => [
                'nobody@example.com',
                'somebody@example.com',
              ],
              'smtp' => {
                'from' => 'bosh@example.com',
                'host' => '127.0.0.90',
                'port' => 25,
                'domain' => 'example.com',
                'tls' => true,
                'auth' => 'tls',
                'user' => 'my-user',
                'password' => 'my-password',
                'interval' => 300,
              }
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('email')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['recipients']).to eq(['nobody@example.com', 'somebody@example.com'])
          expect(plugin['options']['smtp']['from']).to eq('bosh@example.com')
          expect(plugin['options']['smtp']['host']).to eq('127.0.0.90')
          expect(plugin['options']['smtp']['port']).to eq(25)
          expect(plugin['options']['smtp']['domain']).to eq('example.com')
          expect(plugin['options']['smtp']['tls']).to eq(true)
          expect(plugin['options']['smtp']['auth']).to eq('tls')
          expect(plugin['options']['smtp']['user']).to eq('my-user')
          expect(plugin['options']['smtp']['password']).to eq('my-password')
        end
      end

      context 'tsdb' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'tsdb_enabled' => true,
              'tsdb' => {
                'address' => '127.0.0.91',
                'port' => 4223,
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('tsdb')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['host']).to eq('127.0.0.91')
          expect(plugin['options']['port']).to eq(4223)
        end
      end

      context 'cloud_watch' do
        before do
          deployment_manifest_fragment['properties']['hm']['cloud_watch_enabled'] = true
          deployment_manifest_fragment['properties']['aws'] = {
            'access_key_id' => 'my-key',
            'secret_access_key' => 'my-secret',
          }
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('cloud_watch')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['access_key_id']).to eq('my-key')
          expect(plugin['options']['secret_access_key']).to eq('my-secret')
        end
      end

      context 'resurrector' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'resurrector_enabled' => true,
              'resurrector' => {
                'minimum_down_jobs' => 7,
                'percent_threshold' => 70,
                'time_threshold' => 700,
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('resurrector')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['director']).to eq(parsed_yaml['director'])
          expect(plugin['options']['minimum_down_jobs']).to eq(7)
          expect(plugin['options']['percent_threshold']).to eq(70)
          expect(plugin['options']['time_threshold']).to eq(700)
        end
      end

      context 'pagerduty' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'pagerduty_enabled' => true,
              'pagerduty' => {
                'service_key' => 'abcde',
                'http_proxy' => 'http://localhost:3142',
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('pagerduty')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['service_key']).to eq('abcde')
          expect(plugin['options']['http_proxy']).to eq('http://localhost:3142')
        end
      end

      context 'datadog' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'datadog_enabled' => true,
              'datadog' => {
                'api_key' => 'abcdef',
                'application_key' => 'dog-key',
                'pagerduty_service_name' => 'pager-name',
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('data_dog')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['api_key']).to eq('abcdef')
          expect(plugin['options']['application_key']).to eq('dog-key')
          expect(plugin['options']['pagerduty_service_name']).to eq('pager-name')
        end
      end

      context 'riemann' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'riemann_enabled' => true,
              'riemann' => {
                'host' => '127.0.0.1',
                'port' => '5555',
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('riemann')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['host']).to eq('127.0.0.1')
          expect(plugin['options']['port']).to eq('5555')
        end
      end

      context 'graphite' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'graphite_enabled' => true,
              'graphite' => {
                'address' => '192.0.2.1',
                'port' => 12345,
                'prefix' => 'my-prefix',
              },
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('graphite')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['options']['host']).to eq('192.0.2.1')
          expect(plugin['options']['port']).to eq(12345)
          expect(plugin['options']['prefix']).to eq('my-prefix')
        end
      end

      context 'consul_event_forwarder' do
        before do
          deployment_manifest_fragment['properties']['hm'].merge!({
              'consul_event_forwarder_enabled' => true,
              'consul_event_forwarder' => {
                'host' => '192.0.2.2',
                'port' => 2345,
                'protocol' => 'http',
                'ttl_note' => 'none',
                'events' => false,
                'heartbeats_as_alerts' => true,
                'namespace' => 'myns',
                'params' => true,
                'ttl' => 60,
              }
            })
        end

        it 'should render' do
          expect(parsed_yaml['plugins'].length).to eq(4)

          plugin = parsed_yaml['plugins'][3]
          expect(plugin['name']).to eq('consul_event_forwarder')
          expect(plugin['events']).to be_a(Array)
          expect(plugin['name']).to eq('consul_event_forwarder')
          expect(plugin['events']).to eq(['alert', 'heartbeat'])
          expect(plugin['options']['host']).to eq('192.0.2.2')
          expect(plugin['options']['port']).to eq(2345)
          expect(plugin['options']['protocol']).to eq('http')
          expect(plugin['options']['ttl_note']).to eq('none')
          expect(plugin['options']['events']).to eq(false)
          expect(plugin['options']['heartbeats_as_alerts']).to eq(true)
          expect(plugin['options']['namespace']).to eq('myns')
          expect(plugin['options']['params']).to eq(true)
          expect(plugin['options']['ttl']).to eq(60)
        end
      end
    end
  end
end

describe 'tls' do
  describe 'nats_server_ca.pem.erb' do
    it_should_behave_like 'a rendered file' do
      let(:file_name) { '../jobs/health_monitor/templates/nats_server_ca.pem.erb' }
      let(:properties) do
        {
          'properties' => {
            'nats' => {
              'tls' => {
                'ca' => content
              }
            }
          }
        }
      end
    end
  end

  describe 'nats_client_certificate.pem.erb' do
    it_should_behave_like 'a rendered file' do
      let(:file_name) { '../jobs/health_monitor/templates/nats_client_certificate.pem.erb' }
      let(:properties) do
        {
          'properties' => {
            'nats' => {
              'tls' => {
                'health_monitor' => {
                  'certificate' => content
                }
              }
            }
          }
        }
      end
    end
  end

  describe 'nats_client_private_key.erb' do
    it_should_behave_like 'a rendered file' do
      let(:file_name) { '../jobs/health_monitor/templates/nats_client_private_key.erb' }
      let(:properties) do
        {
          'properties' => {
            'nats' => {
              'tls' => {
                'health_monitor' => {
                  'private_key' => content
                }
              }
            }
          }
        }
      end
    end
  end
end
