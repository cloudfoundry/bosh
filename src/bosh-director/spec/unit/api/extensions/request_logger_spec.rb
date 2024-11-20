require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Extensions::RequestLogger do
      include Rack::Test::Methods
      let(:config_hash) { SpecHelper.spec_get_director_config }
      let(:config) do
        config = Config.load_hash(config_hash)
        identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
        allow(config).to receive(:identity_provider).and_return(identity_provider)
        config
      end
      let(:app) { Support::TestController.new(config, true) }
      let(:test_path) { '/test_route' }
      let(:authorize!) {} # not authorized
      let(:query) { nil }
      let(:audit_logger) { instance_double(Bosh::Director::AuditLogger) }

      before { allow(Socket).to receive(:gethostname).and_return('director-hostname') }
      before do
        allow(Socket).to receive(:ip_address_list).and_return(
          [
            instance_double(Addrinfo, ip_address: '127.0.0.1', ip?: true, ipv4_loopback?: true, ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: '10.10.0.6', ip?: true, ipv4_loopback?: false, ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: '::1', ip?: true, ipv4_loopback?: false, ipv6_loopback?: true),
            instance_double(Addrinfo, ip_address: 'fe80::10bf:eff:fe2c:7405%eth0', ip?: true, ipv4_loopback?: false,
                                      ipv6_loopback?: false),
            instance_double(Addrinfo, ip_address: 'no-ip', ip?: false, ipv4_loopback?: false, ipv6_loopback?: false),
          ],
        )
      end

      let(:expected_status) { 401 }

      let(:host_header_value) { 'request-logger-spec.example.org' }
      let(:log_string) do
        log_string = nil
        allow(Bosh::Director::AuditLogger).to receive(:instance).and_return(audit_logger)
        allow(audit_logger).to receive(:info) do |log|
          log_string = log
        end
        authorize!
        header 'random-header',      'should-be-ignored'
        header 'HOST',               host_header_value
        header 'X_REAL_IP',          '5.6.7.8'
        header 'X_FORWARDED_FOR',    '1.2.3.4'
        header 'X_FORWARDED_PROTO',  'https'
        header 'USER_AGENT',         'Fake Agent'
        expect(get(test_path, query).status).to eq(expected_status)
        log_string
      end

      context 'when not enabled' do
        it 'should not log to audit logger' do
          expect(log_string).to be_nil
        end
      end

      context 'when enabled' do
        before { config_hash['log_access_events'] = true }

        describe 'log_request_to_auditlog' do
          context 'CEF Header' do
            it 'includes CEF version' do
              expect(log_string).to include('CEF:0|')
            end

            it 'includes Device Vendor' do
              expect(log_string).to include('|CloudFoundry|')
            end

            it 'includes Device Product' do
              expect(log_string).to include('|BOSH|')
            end

            it 'includes Device Version' do
              expect(log_string).to include('|0.0.2|')
            end

            it 'includes Signature ID' do
              expect(log_string).to include('|director_api|')
            end

            it 'includes Name' do
              expect(log_string).to include('|/test_route|')
            end

            it 'includes Severity' do
              expect(log_string).to include('|7|')
            end
          end

          context 'CEF extension' do
            it 'includes request ip' do
              expect(log_string).to include('src=1.2.3.4')
            end

            it 'includes port info' do
              expect(log_string).to include('spt=8081')
            end

            it 'includes host name' do
              expect(log_string).to include('shost=director-hostname')
            end

            it 'includes director ips' do
              expect(log_string).to include('cs1=10.10.0.6,fe80::10bf:eff:fe2c:7405%eth0 cs1Label=ips')
            end

            it 'includes http headers' do
              expect(log_string).to include(
                                      [
                                        "cs2=HOST=#{host_header_value}",
                                        "X_REAL_IP=5.6.7.8",
                                        "X_FORWARDED_FOR=1.2.3.4",
                                        "X_FORWARDED_PROTO=https",
                                        "USER_AGENT=Fake Agent cs2Label=httpHeaders",
                                      ].join('&')
                                    )
            end

            it 'includes authorization type' do
              expect(log_string).to include('cs3=none cs3Label=authType')
            end

            it 'includes response status' do
              expect(log_string).to include("cs4=#{expected_status} cs4Label=responseStatus")
            end

            context 'when auth is provided' do
              let(:expected_status) { 200 }

              context 'basic' do
                let(:authorize!) { basic_authorize('admin', 'admin') }

                it 'includes username' do
                  expect(log_string).to include('duser=admin')
                end
              end

              context 'uaa' do
                let(:authorize!) { basic_authorize('client-username', 'client-username') }
                it 'includes client info' do
                  expect(log_string).to include('requestClientApplication=client-id')
                end
              end
            end

            context 'when the response status code is less than 400' do
              let(:authorize!) { basic_authorize('admin', 'admin') }
              let(:expected_status) { 200 }

              it 'does not include status reason' do
                expect(log_string).to_not include('cs5Label=statusReason')
                expect(log_string).to_not include('cs5=')
              end
            end

            context 'when the response status code is greater than or equal to 400' do
              let(:test_path) { '/exceptional' }

              it 'included status reason' do
                expect(log_string).to include('cs5Label=statusReason')
                expect(log_string).to include("cs5=Not authorized: '/exceptional'")
              end
            end
          end
        end
      end
    end
  end
end
