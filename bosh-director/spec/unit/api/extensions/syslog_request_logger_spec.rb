require 'spec_helper'
require 'rack/test'
require 'timecop'


module Bosh::Director
  module Api
    if RUBY_VERSION.to_i > 1
      describe Extensions::SyslogRequestLogger do
        include Rack::Test::Methods
        let(:config_hash) { Psych.load(spec_asset('test-director-config.yml')) }
        let(:config) do
          config = Config.load_hash(config_hash)
          identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
          allow(config).to receive(:identity_provider).and_return(identity_provider)
          config
        end
        let(:app) { Support::TestController.new(config, true) }
        let(:test_path) { '/test_route' }
        let(:authorize!) {} #not authorized
        let(:query) { nil }
        let(:syslog) { instance_double(Syslog::Logger) }

        before { allow(Syslog::Logger).to receive(:new).with('bosh.director').and_return(syslog) }
        before { allow(Socket).to receive(:gethostname).and_return('director-hostname') }
        before do
          allow(Socket).to receive(:ip_address_list).and_return([
            instance_double(Addrinfo, ip_address: '127.0.0.1', ip?: true, ipv4_loopback?: true, ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: '10.10.0.6', ip?: true, ipv4_loopback?: false, ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: '::1', ip?: true, ipv4_loopback?: false, ipv6_loopback?: true),
            instance_double(Addrinfo, ip_address: 'fe80::10bf:eff:fe2c:7405%eth0', ip?: true, ipv4_loopback?: false, ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: 'no-ip', ip?: false, ipv4_loopback?: false, ipv6_loopback?: false)
          ])
        end
        let(:expected_status) { 401 }

        let(:log_hash) do
          authorize!
          hash = nil
          allow(syslog).to receive(:info) do |json_string|
            hash = JSON.parse(json_string)
          end
          header 'random-header',      'should-be-ignored'
          header 'HOST',               'fake-host.com'
          header 'X_REAL_IP',          '5.6.7.8'
          header 'X_FORWARDED_FOR',    '1.2.3.4'
          header 'X_FORWARDED_PROTO',  'https'
          header 'USER_AGENT',         'Fake Agent'
          expect(get(test_path, query).status).to eq(expected_status)
          hash
        end

        context 'when not enabled' do
          it 'should not log to syslog' do
            expect(log_hash).to be_nil
          end
        end

        context 'when enabled' do
          before { config_hash['log_access_events_to_syslog'] = true }

          describe 'log_request_to_syslog' do
            it 'should include the type of access' do
              expect(log_hash['type']).to eq('api')
            end

            it 'should log the username and the authorization type' do
              expect(log_hash['auth']).to eq({'type' => 'none'})
            end

            it 'should log to response status code' do
              expect(log_hash['client']['ip']).to eq('1.2.3.4')
            end

            context 'http section' do
              it 'should log request method' do
                expect(log_hash['http']['verb']).to eq('GET')
              end

              it 'should log to request path' do
                expect(log_hash['http']['path']).to eq('/test_route')
              end

              context 'when the response status code is > 399' do
                it 'should log response body in the reason field' do
                  expect(log_hash['http']['status']['reason']).to eq("Not authorized: '/test_route'\n")
                end
              end

              it 'should log the headers' do
                expect(log_hash['http']['headers']).to eq([
                      ['HOST', 'fake-host.com'],
                      ['X_REAL_IP', '5.6.7.8'],
                      ['X_FORWARDED_FOR', '1.2.3.4'],
                      ['X_FORWARDED_PROTO', 'https'],
                      ['USER_AGENT', 'Fake Agent']
                    ])
              end
            end

            context 'component section' do
              it 'should log component name' do
                expect(log_hash['component']['name']).to eq('director')
              end

              it 'should log component version' do
                expect(log_hash['component']['version']).to eq(Bosh::Director::VERSION)
              end

              it 'should log component port' do
                expect(log_hash['component']['port']).to eq(8081)
              end

              it 'should log component hostname' do
                expect(log_hash['component']['hostname']).to eq('director-hostname')
              end

              it 'should log component hostname' do
                expect(log_hash['component']['hostname']).to eq('director-hostname')
              end

              it 'should log the director ips' do
                expect(log_hash['component']['ips']).to eq(['10.10.0.6', 'fe80::10bf:eff:fe2c:7405%eth0'])
              end
            end

            context 'when there is no query string' do
              it 'should not include the query key' do
                expect(log_hash['http'].has_key?('query')).to eq(false)
              end
            end

            context 'when there is a query string' do
              let(:query) { {'foo' => 'bar'} }
              it 'should include the query parameters' do
                expect(log_hash['http']['query']).to eq('foo=bar')
              end
            end

            context 'when the access happened' do
              let(:time_now) { Time.now }
              before { Timecop.freeze(time_now) }
              after { Timecop.return }
              it 'should log the time of the request' do
                expect(log_hash['timestamp']).to eq(Time.now.utc.to_s)
              end
            end

            context 'when auth is provided' do
              let(:authorize!) { basic_authorize('admin', 'admin') }
              let(:expected_status) { 200 }

              it 'should log the username' do
                expect(log_hash['auth']['user']).to eq('admin')
              end

              it 'should log the authorization type' do
                expect(log_hash['auth']['type']).to eq('test-auth-type')
              end

              context 'when the user has no client' do
                it 'should not include the client key' do
                  expect(log_hash['auth'].has_key?('client')).to be(false)
                end
              end

              context 'when the user has no user' do
                let(:authorize!) { basic_authorize('client-username', 'client-username') }
                it 'should not include the username key' do
                  expect(log_hash['auth'].has_key?('user')).to be(false)
                end
              end

              context 'when the logged in user has a client' do
                let(:authorize!) { basic_authorize('client-username', 'client-username') }
                it 'should include client key, value' do
                  expect(log_hash['auth']['client']).to eq('client-id')
                end
              end

              context 'when the response status code is less than 400' do
                it 'should not include the http.status.reason' do
                  expect(log_hash['http']['status'].has_key?('reason')).to be(false)
                end
              end

              it 'should log to response status code' do
                expect(log_hash['http']['status']['code']).to eq(200)
              end

              context 'when response code is greater than 399' do
                context 'when the response body is greater than 500 characters' do
                  let(:test_path) { '/exceptional' }
                  let(:expected_status) { 500 }
                  it 'returns the first 500 characters' do
                    expect(log_hash['http']['status']['reason']).to start_with('{"code":100,"description":"jUgKUxon')
                    expect(log_hash['http']['status']['reason'].length).to eq(500)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
