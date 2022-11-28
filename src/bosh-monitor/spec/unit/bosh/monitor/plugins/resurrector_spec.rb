require_relative '../../../../spec_helper'

module Bosh::Monitor::Plugins
  describe Resurrector do
    include Support::UaaHelpers
    let(:options) do
      {
        'director' => {
          'endpoint' => 'http://foo.bar.com:25555',
          'user' => 'user',
          'password' => 'password',
          'client_id' => 'client-id',
          'client_secret' => 'client-secret',
          'ca_cert' => 'ca-cert',
        },
      }
    end
    let(:plugin) { Bhm::Plugins::Resurrector.new(options) }
    let(:uri) { 'http://foo.bar.com:25555' }
    let(:status_uri) { "#{uri}/info" }
    let(:tasks_uri) { "#{uri}/tasks?deployment=d&state=queued,processing&verbose=2" }
    let(:tasks_body) do
      '[{
        "id": 60337,
        "state": "processing",
        "description": "create deployment",
        "timestamp": null,
        "started_at": 1669644079,
        "result": null,
        "user": "admin",
        "deployment": "d",
        "context_id": ""
      }]'
    end

    before do
      stub_request(:get, tasks_uri).to_return(lambda do |request|
        if request.headers.fetch('Authorization') || request.headers.fetch('authorization')
          { status: 200, body: tasks_body }
        else
          { status: 401, body: '{"error": "unauthorized"}' }
        end
      end)
      stub_request(:get, status_uri)
        .to_return(status: 200, body: JSON.dump('user_authentication' => user_authentication))
    end

    let(:alert) do
      Bhm::Events::Base.create!(:alert, alert_payload(
                                          category: Bosh::Monitor::Events::Alert::CATEGORY_DEPLOYMENT_HEALTH,
                                          deployment: 'd',
                                          jobs_to_instance_ids: { 'j1' => %w[i1 i2], 'j2' => %w[i3 i4] },
                                          severity: 1,
                                        ))
    end

    let(:user_authentication) do
      {}
    end

    context 'when the event machine reactor is not running' do
      it 'should not start' do
        expect(plugin.run).to be(false)
      end
    end

    context 'when the event machine reactor is running' do
      around do |example|
        EM.run do
          example.call
          EM.stop
        end
      end

      context 'when there are already scan and fix tasks scheduled for a deployment' do
        let(:event_processor) { Bhm::EventProcessor.new }
        let(:state) do
          double(Bhm::Plugins::ResurrectorHelper::DeploymentState, managed?: true, meltdown?: false, summary: 'summary')
        end

        before do
          Bhm.event_processor = event_processor
          @don = double(Bhm::Plugins::ResurrectorHelper::AlertTracker, record: nil, state_for: state)
          expect(Bhm::Plugins::ResurrectorHelper::AlertTracker).to receive(:new).and_return(@don)
        end

        context 'with a scan task already queued' do
          let(:tasks_body) do
            '[{
              "id": 12345,
              "state": "queued",
              "description": "scan and fix",
              "timestamp": 1654794744,
              "started_at": 0,
              "result": "",
              "user": "admin",
              "deployment": "d",
              "context_id": ""
            }]'
          end
          it 'will not add an additional queued task' do
            plugin.run

            expect(plugin).not_to receive(:send_http_put_request)

            plugin.process(alert)
          end
        end

        context 'with a scan task being processed' do
          let(:tasks_body) do
            '[{
              "id": 12345,
              "state": "processing",
              "description": "scan and fix",
              "timestamp": 1654794744,
              "started_at": 0,
              "result": "",
              "user": "admin",
              "deployment": "d",
              "context_id": ""
            }]'
          end
          it 'will not add an additional queued task' do
            plugin.run

            expect(plugin).not_to receive(:send_http_put_request)

            plugin.process(alert)
          end
        end
      end

      context 'alert of CATEGORY_DEPLOYMENT_HEALTH' do
        let(:event_processor) { Bhm::EventProcessor.new }
        let(:state) do
          double(Bhm::Plugins::ResurrectorHelper::DeploymentState, managed?: true, meltdown?: false, summary: 'summary')
        end

        before do
          Bhm.event_processor = event_processor
          @don = double(Bhm::Plugins::ResurrectorHelper::AlertTracker, record: nil, state_for: state)
          expect(Bhm::Plugins::ResurrectorHelper::AlertTracker).to receive(:new).and_return(@don)
        end

        it 'gets delivered' do
          plugin.run

          request_url = "#{uri}/deployments/d/scan_and_fix"
          request_data = {
            head: {
              'Content-Type' => 'application/json',
              'authorization' => %w[user password],
            },
            body: '{"jobs":{"j1":["i1","i2"],"j2":["i3","i4"]}}',
          }
          expect(plugin).to receive(:send_http_put_request).with(request_url, request_data)

          plugin.process(alert)
        end

        context 'when auth provider is using UAA token issuer' do
          let(:user_authentication) do
            {
              'type' => 'uaa',
              'options' => {
                'url' => 'uaa-url',
              },
            }
          end

          before do
            token_issuer = instance_double(CF::UAA::TokenIssuer)

            allow(File).to receive(:exist?).with('ca-cert').and_return(true)
            allow(File).to receive(:read).with('ca-cert').and_return('test')

            allow(CF::UAA::TokenIssuer).to receive(:new).with(
              'uaa-url', 'client-id', 'client-secret', ssl_ca_file: 'ca-cert'
            ).and_return(token_issuer)
            allow(token_issuer).to receive(:client_credentials_grant)
              .and_return(token)
          end
          let(:token) { uaa_token_info('fake-token-id') }

          it 'uses UAA token' do
            plugin.run

            request_url = "#{uri}/deployments/d/scan_and_fix"
            request_data = {
              head: {
                'Content-Type' => 'application/json',
                'authorization' => token.auth_header,
              },
              body: '{"jobs":{"j1":["i1","i2"],"j2":["i3","i4"]}}',
            }
            expect(plugin).to receive(:send_http_put_request).with(request_url, request_data)

            plugin.process(alert)
          end
        end

        context 'while melting down' do
          let(:state) do
            double(Bhm::Plugins::ResurrectorHelper::DeploymentState, managed?: false, meltdown?: true, summary: 'summary')
          end

          it 'does not send requests to scan and fix' do
            plugin.run
            expect(plugin).not_to receive(:send_http_put_request)
            plugin.process(alert)
          end

          it 'sends alerts to the EventProcessor' do
            expected_time = Time.new
            allow(Time).to receive(:now).and_return(expected_time)
            alert_option = {
              severity: 1,
              title: 'We are in meltdown',
              summary: 'Skipping resurrection for instances: j1/i1, j1/i2, j2/i3, j2/i4; summary',
              source: 'HM plugin resurrector',
              deployment: 'd',
              created_at: expected_time.to_i,
            }
            expect(event_processor).to receive(:process).with(:alert, alert_option)
            plugin.run
            plugin.process(alert)
          end
        end

        context 'when resurrection is disabled for all instance_groups' do
          let(:resurrection_manager) { double(Bosh::Monitor::ResurrectionManager, resurrection_enabled?: false) }
          before { allow(Bhm).to receive(:resurrection_manager).and_return(resurrection_manager) }

          it 'does not send requests to scan and fix' do
            plugin.run
            expect(plugin).not_to receive(:send_http_put_request)
            plugin.process(alert)
          end

          it 'sends alerts to the EventProcessor' do
            expected_time = Time.new
            allow(Time).to receive(:now).and_return(expected_time)
            alert_option = {
              severity: 1,
              title: 'Resurrection is disabled by resurrection config',
              summary: 'Skipping resurrection for instances: j1/i1, j1/i2, j2/i3, j2/i4; summary because of resurrection config',
              source: 'HM plugin resurrector',
              deployment: 'd',
              created_at: expected_time.to_i,
            }
            expect(event_processor).to receive(:process).with(:alert, alert_option)
            plugin.run
            plugin.process(alert)
          end
        end

        context 'when resurrection is disabled for some instance_groups' do
          let(:resurrection_manager) { double(Bosh::Monitor::ResurrectionManager) }

          before do
            allow(resurrection_manager).to receive(:resurrection_enabled?).with('d', 'j1').and_return(false)
            allow(resurrection_manager).to receive(:resurrection_enabled?).with('d', 'j2').and_return(true)
            allow(Bhm).to receive(:resurrection_manager).and_return(resurrection_manager)
          end

          it 'sends request to scan and fix for only enabled instance_groups' do
            plugin.run

            request_url = "#{uri}/deployments/d/scan_and_fix"
            request_data = {
              head: {
                'Content-Type' => 'application/json',
                'authorization' => %w[user password],
              },
              body: '{"jobs":{"j2":["i3","i4"]}}',
            }
            expect(plugin).to receive(:send_http_put_request).with(request_url, request_data)

            plugin.process(alert)
          end

          it 'sends correct alerts to the EventProcessor' do
            allow(plugin).to receive(:send_http_put_request)
            expected_time = Time.new
            allow(Time).to receive(:now).and_return(expected_time)
            alert_recreate = {
              severity: 4,
              title: 'Scan unresponsive VMs',
              summary: 'Notifying Director to scan instances: j2/i3, j2/i4; summary',
              source: 'HM plugin resurrector',
              deployment: 'd',
              created_at: expected_time.to_i,
            }
            alert_skip = {
              severity: 1,
              title: 'Resurrection is disabled by resurrection config',
              summary: 'Skipping resurrection for instances: j1/i1, j1/i2; summary because of resurrection config',
              source: 'HM plugin resurrector',
              deployment: 'd',
              created_at: expected_time.to_i,
            }

            expect(event_processor).to receive(:process).with(:alert, alert_recreate)
            expect(event_processor).to receive(:process).with(:alert, alert_skip)

            plugin.run
            plugin.process(alert)
          end
        end

        context 'without deployment or jobs_to_instance_ids' do
          let(:alert) { Bhm::Events::Base.create!(:alert, alert_payload) }

          it 'does not send request to scan and fix' do
            plugin.run

            expect(plugin).not_to receive(:send_http_put_request)

            plugin.process(alert)
          end
        end
      end

      context 'alert of CATEGORY_VM_HEALTH' do
        let(:alert) do
          Bhm::Events::Base.create!(:alert, alert_payload(category: Bosh::Monitor::Events::Alert::CATEGORY_VM_HEALTH))
        end

        it 'does not send request to scan and fix' do
          plugin.run

          expect(plugin).not_to receive(:send_http_put_request)

          plugin.process(alert)
        end
      end

      context 'when director status is not 200' do
        before do
          stub_request(:get, status_uri).to_return({ status: 500, headers: {}, body: 'Failed' })
        end

        it 'returns false' do
          plugin.run

          expect(plugin).not_to receive(:send_http_put_request)

          plugin.process(alert)
        end

        context 'when director starts responding' do
          before do
            state = double(Bhm::Plugins::ResurrectorHelper::DeploymentState, managed?: true, meltdown?: false, summary: 'summary')
            expect(Bhm::Plugins::ResurrectorHelper::DeploymentState).to receive(:new).and_return(state)
          end

          it 'starts sending alerts' do
            plugin.run

            expect(plugin).to receive(:send_http_put_request).once

            stub_request(:get, status_uri).to_return({ status: 500 })
            plugin.process(alert) # fails to send request

            stub_request(:get,
                         status_uri).to_return({ status: 200, body: JSON.dump('user_authentication' => user_authentication) })
            plugin.process(alert)
          end
        end
      end
    end
  end
end
