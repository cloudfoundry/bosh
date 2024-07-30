require 'spec_helper'
require 'netaddr'

module Bosh
  module Director
    class FakeRufusScheduler
      attr_reader :interval_duration
      def interval(interval_duration, &blk)
        @interval_duration = interval_duration
        @blk = blk
      end

      def tick
        @blk.call
      end
    end

    describe MetricsCollector do
      let(:scheduler) { FakeRufusScheduler.new }
      let(:metrics_collector) { MetricsCollector.new(Config.load_hash(SpecHelper.spec_get_director_config)) }
      let(:resurrector_manager) { instance_double(Api::ResurrectorManager) }

      before do
        allow(Rufus::Scheduler).to receive(:new).and_return(scheduler)
        allow(Api::ResurrectorManager).to receive(:new).and_return(resurrector_manager)
        allow(resurrector_manager).to receive(:pause_for_all?).and_return(false, true, false)
        allow(Api::ConfigManager).to receive(:deploy_config_enabled?).and_return(true, false)
        stub_request(:get, /unresponsive_agents/)
          .to_return(status: 200, body: JSON.dump('flaky_deployment' => 1, 'good_deployment' => 0))
      end

      after do
        Prometheus::Client.registry.unregister(:bosh_resurrection_enabled)
        Prometheus::Client.registry.unregister(:bosh_deploy_config_enabled)
        Prometheus::Client.registry.unregister(:bosh_tasks_total)
        Prometheus::Client.registry.unregister(:bosh_networks_dynamic_ips_total)
        Prometheus::Client.registry.unregister(:bosh_networks_dynamic_free_ips_total)
        Prometheus::Client.registry.unregister(:bosh_unresponsive_agents)
      end

      describe 'start' do
        describe 'bosh_resurrection_enabled' do
          it 'populates the metrics every 30 seconds' do
            metrics_collector.start
            expect(scheduler.interval_duration).to eq('30s')
            expect(Prometheus::Client.registry.get(:bosh_resurrection_enabled).get).to eq(1)
            scheduler.tick
            expect(Prometheus::Client.registry.get(:bosh_resurrection_enabled).get).to eq(0)
          end
        end

        describe 'deploy_config_enabled' do
          it 'populates the metrics every 30 seconds' do
            metrics_collector.start
            expect(scheduler.interval_duration).to eq('30s')
            expect(Prometheus::Client.registry.get(:bosh_deploy_config_enabled).get).to eq(1)
            scheduler.tick
            expect(Prometheus::Client.registry.get(:bosh_deploy_config_enabled).get).to eq(0)
          end
        end

        describe 'network metrics' do
          let(:manual_network_spec) do
            {
              'name' => 'my-manual-network',
              'type' => 'manual',
              'subnets' => [
                {
                  'range' => '192.168.1.0/28',
                  'gateway' => '192.168.1.1',
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'static' => ['192.168.1.4'],
                  'reserved' => ['192.168.1.6-192.168.1.7'],
                  'cloud_properties' => {},
                  'az' => 'az-1',
                },
              ],
            }
          end

          let(:weird_name_network_spec) do
            {
              'name' => '::WEIRD-manual-network!!!!',
              'type' => 'manual',
              'subnets' => [
                {
                  'range' => '192.168.1.0/28',
                  'gateway' => '192.168.1.1',
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'static' => ['192.168.1.4'],
                  'reserved' => ['192.168.1.6-192.168.1.7'],
                  'cloud_properties' => {},
                  'az' => 'az-1',
                },
              ],
            }
          end

          let(:dynamic_network_spec) do
            {
              'name' => 'my-dynamic-network',
              'type' => 'dynamic',
              'subnets' => [
                {
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'cloud_properties' => {},
                  'az' => 'az-1',
                },
              ],
            }
          end

          let(:vip_network_spec) do
            {
              'name' => 'my-vip-network',
              'type' => 'vip',
              'subnets' => [
                {
                  'dns' => ['192.168.1.1', '192.168.1.2'],
                  'cloud_properties' => {},
                  'az' => 'az-1',
                },
              ],
            }
          end

          let(:older_network_spec) { manual_network_spec.merge('name' => 'older-network') }
          let(:az) { { 'name' => 'az-1' } }

          before do
            Models::Config.make(:cloud, name: 'some-cloud-config', content: YAML.dump(
              'azs' => [az],
              'vm_types' => [],
              'disk_types' => [],
              'networks' => [older_network_spec],
              'vm_extensions' => [],
              'compilation' => { 'az' => 'az-1', 'network' => manual_network_spec['name'], 'workers' => 3 },
            ))

            Models::Config.make(:cloud, name: 'some-cloud-config', content: YAML.dump(
              'azs' => [az],
              'vm_types' => [],
              'disk_types' => [],
              'networks' => [dynamic_network_spec, manual_network_spec, vip_network_spec, weird_name_network_spec],
              'vm_extensions' => [],
              'compilation' => { 'az' => 'az-1', 'network' => manual_network_spec['name'], 'workers' => 3 },
            ))
          end

          it 'emits the total number of dynamic IPs in the network' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_ips_total)
            expect(metric.get(labels: { name: 'my_manual_network' })).to eq(10)
          end

          it 'emits the number of free dynamic IPs' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_free_ips_total)
            expect(metric.get(labels: { name: 'my_manual_network' })).to eq(10)
          end

          it 'makes names prometheus compatible' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_free_ips_total)
            expect(metric.get(labels: { name: 'weird_manual_network' })).to eq(10)
          end

          context 'when there are deployed VMs' do
            let(:deployment) { Models::Deployment.make }
            let(:instance) { Models::Instance.make(deployment: deployment) }
            let(:vm) do
              Models::Vm.make(cid: 'fake-vm-cid', agent_id: 'fake-agent-id', instance_id: instance.id, created_at: Time.now)
            end

            before do
              Models::IpAddress.make(
                instance_id: instance.id,
                vm_id: vm.id,
                address_str: NetAddr::CIDR.create('192.168.1.5').to_i.to_s,
                network_name: manual_network_spec['name'],
                static: false,
              )
            end

            it 'accounts for used IPs' do
              metrics_collector.start
              metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_free_ips_total)
              expect(metric.get(labels: { name: 'my_manual_network' })).to eq(9)
            end

            context 'when deployed VMs are using static ips' do
              before do
                Models::IpAddress.make(
                  instance_id: instance.id,
                  vm_id: vm.id,
                  address_str: NetAddr::CIDR.create('192.168.1.4').to_i.to_s,
                  network_name: manual_network_spec['name'],
                  static: true,
                )
              end

              it 'does not double count the static ips' do
                metrics_collector.start
                metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_free_ips_total)
                expect(metric.get(labels: { name: 'my_manual_network' })).to eq(9)
              end
            end
          end

          context 'missing values' do
            context 'there are empty values defined in some cloud-config' do
              before do
                Models::Config.make(:cloud, name: 'yacc', content: YAML.dump(
                  'azs' => [],
                  'vm_types' => [],
                  'disk_types' => [],
                  'vm_extensions' => [],
                  'networks' => [],
                ))
              end

              it 'can still get metrics without errors' do
                metrics_collector.start
                metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_ips_total)
                expect(metric.get(labels: { name: 'my_manual_network' })).to eq(10)
              end
            end

            context 'there are no fields defined in some cloud-config' do
              before do
                Models::Config.make(:cloud, name: 'yacc', content: YAML.dump({}))
              end

              it 'can still get metrics without errors' do
                metrics_collector.start
                metric = Prometheus::Client.registry.get(:bosh_networks_dynamic_ips_total)
                expect(metric.get(labels: { name: 'my_manual_network' })).to eq(10)
              end
            end
          end
        end

        describe 'vm metrics' do
          it 'emits the number of unresponsive agents for each deployment' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_unresponsive_agents)
            expect(metric.get(labels: { name: 'flaky_deployment' })).to eq(1)
            expect(metric.get(labels: { name: 'good_deployment' })).to eq(0)
          end

          context 'when the health monitor returns a non 200 response' do
            before do
              stub_request(:get, '127.0.0.1:12345/unresponsive_agents')
                .to_return(status: 404)
            end

            it 'does not emit the vm metrics' do
              metrics_collector.start
              metric = Prometheus::Client.registry.get(:bosh_unresponsive_agents)
              expect(metric.values).to be_empty
            end
          end

          context 'when the health monitor returns a non-json response' do
            before do
              stub_request(:get, '127.0.0.1:12345/unresponsive_agents')
                .to_return(status: 200, body: JSON.dump('bad response'))
            end

            it 'does not emit the vm metrics' do
              metrics_collector.start
              metric = Prometheus::Client.registry.get(:bosh_unresponsive_agents)
              expect(metric.values).to be_empty
            end
          end

          context 'when a deployment is deleted after metrics are gathered' do
            before do
              stub_request(:get, /unresponsive_agents/)
                .to_return(status: 200, body: JSON.dump('flaky_deployment' => 1, 'good_deployment' => 0))
              metrics_collector.start

              stub_request(:get, /unresponsive_agents/)
                .to_return(status: 200, body: JSON.dump('good_deployment' => 0))
              scheduler.tick
            end

            it 'resets the metrics for the deleted deployment' do
              metric = Prometheus::Client.registry.get(:bosh_unresponsive_agents)
              expect(metric.get(labels: { name: 'flaky_deployment' })).to eq(0)
            end
          end
        end

        describe 'task metrics' do
          let!(:task1) { Models::Task.make(state: 'queued', type: 'foobar') }
          let!(:task2) { Models::Task.make(state: 'queued', type: 'foobaz') }
          let!(:task3) { Models::Task.make(state: 'processing', type: 'foobar') }
          let!(:task4) { Models::Task.make(state: 'processing', type: 'foobar') }
          let!(:task5) { Models::Task.make(state: 'processing', type: 'foobaz') }

          it 'populates metrics for processing tasks by type' do
            metrics_collector.start
            metric = Prometheus::Client.registry.get(:bosh_tasks_total)
            expect(metric.get(labels: { state: 'queued', type: 'foobar' })).to eq(1)
            expect(metric.get(labels: { state: 'queued', type: 'foobaz' })).to eq(1)
            expect(metric.get(labels: { state: 'processing', type: 'foobar' })).to eq(2)
            expect(metric.get(labels: { state: 'processing', type: 'foobaz' })).to eq(1)

            task2.update(state: 'processing')
            scheduler.tick

            metric = Prometheus::Client.registry.get(:bosh_tasks_total)
            expect(metric.get(labels: { state: 'queued', type: 'foobaz' })).to eq(0)
            expect(metric.get(labels: { state: 'processing', type: 'foobaz' })).to eq(2)
          end
        end
      end
    end
  end
end
