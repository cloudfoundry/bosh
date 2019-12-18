require 'spec_helper'

module Bosh
  module Director
    describe MetricsCollector do
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

      let(:scheduler) { FakeRufusScheduler.new }
      let(:metrics_collector) { MetricsCollector.new(Config.load_hash(SpecHelper.spec_get_director_config)) }
      let(:resurrector_manager) { instance_double(Api::ResurrectorManager) }

      before do
        allow(Rufus::Scheduler).to receive(:new).and_return(scheduler)
        allow(Api::ResurrectorManager).to receive(:new).and_return(resurrector_manager)
        allow(resurrector_manager).to receive(:pause_for_all?).and_return(false, true, false)
      end

      after do
        Prometheus::Client.registry.unregister(:bosh_resurrection_enabled)
        Prometheus::Client.registry.unregister(:bosh_tasks_total)
        Prometheus::Client.registry.unregister(:bosh_networks_dynamic_ips_total)
        Prometheus::Client.registry.unregister(:bosh_networks_dynamic_free_ips_total)
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
            expect(metric.get(labels: { state: 'processing', type: 'foobaz' })).to eq(2)
          end
        end
      end
    end
  end
end
