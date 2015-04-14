require 'spec_helper'

class VSphereCloud::Resources
  describe Cluster do
    subject(:cluster) do
      VSphereCloud::Resources::Cluster.new(
        datacenter,
        /eph/,
        /persist/,
        1.0,
        cluster_config,
        properties,
        logger,
        client
      )
    end

    let(:datacenter) { instance_double('VSphereCloud::Resources::Datacenter') }

    let(:log_output) { StringIO.new("") }
    let(:logger) { Logger.new(log_output) }
    let(:client) { instance_double('VSphereCloud::Client', cloud_searcher: cloud_searcher) }
    let(:cloud_searcher) { instance_double('VSphereCloud::CloudSearcher') }

    let(:cluster_config) do
      instance_double(
        'VSphereCloud::ClusterConfig',
        name: 'fake-cluster-name',
        resource_pool: 'fake-resource-pool',
      )
    end

    let(:properties) do
      {
        :obj => cluster_mob,
        'host' => cluster_hosts,
        'datastore' => 'fake-datastore-name',
        'resourcePool' => fake_resource_pool_mob,
      }
    end
    let(:cluster_mob) { instance_double('VimSdk::Vim::ClusterComputeResource') }
    let(:cluster_hosts) { [instance_double('VimSdk::Vim::HostSystem')] }
    let(:fake_resource_pool_mob) { instance_double('VimSdk::Vim::ResourcePool') }

    let(:fake_resource_pool) do
      instance_double('VSphereCloud::Resources::ResourcePool',
                      mob: fake_resource_pool_mob
      )
    end
    let(:fake_resource_pool_mob) { instance_double('VimSdk::Vim::ResourcePool') }

    let(:ephemeral_store_properties) { {'name' => 'ephemeral_1', 'summary.freeSpace' => 15000 * BYTES_IN_MB} }
    let(:ephemeral_store_2_properties) { {'name' => 'ephemeral_2', 'summary.freeSpace' => 25000 * BYTES_IN_MB} }
    let(:persistent_store_properties) { {'name' => 'persistent_1', 'summary.freeSpace' => 10000 * BYTES_IN_MB, 'summary.capacity' => 20000 * BYTES_IN_MB} }
    let(:persistent_store_2_properties) { {'name' => 'persistent_2', 'summary.freeSpace' => 20000 * BYTES_IN_MB, 'summary.capacity' => 40000 * BYTES_IN_MB} }

    let(:other_store_properties) { { 'name' => 'other' } }

    let(:fake_datastore_properties) do
      {
        instance_double('VimSdk::Vim::Datastore') => ephemeral_store_properties,
        instance_double('VimSdk::Vim::Datastore') => ephemeral_store_2_properties,
        instance_double('VimSdk::Vim::Datastore') => persistent_store_properties,
        instance_double('VimSdk::Vim::Datastore') => persistent_store_2_properties,
        instance_double('VimSdk::Vim::Datastore') => other_store_properties,
      }
    end

    let(:fake_runtime_info) do
      instance_double(
        'VimSdk::Vim::ResourcePool::RuntimeInfo',
        overall_status: 'red',
      )
    end

    before do
      allow(ResourcePool).to receive(:new).with(
        client, logger, cluster_config, fake_resource_pool_mob
      ).and_return(fake_resource_pool)

      allow(cloud_searcher).to receive(:get_properties).with(
        'fake-datastore-name', VimSdk::Vim::Datastore, Datastore::PROPERTIES
      ).and_return(fake_datastore_properties)

      allow(cloud_searcher).to receive(:get_properties).with(
        fake_resource_pool_mob, VimSdk::Vim::ResourcePool, "summary"
      ).and_return({
        'summary' => instance_double('VimSdk::Vim::ResourcePool::Summary', runtime: fake_runtime_info)
      })
    end

    describe '#initialize' do
      describe 'datastores' do
        it 'places each matching datastore in the appropriate array' do
          ephemeral_datastores = cluster.ephemeral_datastores
          expect(ephemeral_datastores.keys).to match_array(['ephemeral_1', 'ephemeral_2'])
          expect(ephemeral_datastores['ephemeral_1'].name).to eq('ephemeral_1')
          expect(ephemeral_datastores['ephemeral_2'].name).to eq('ephemeral_2')

          persistent_datastores = cluster.persistent_datastores
          expect(persistent_datastores.keys).to match_array(['persistent_1', 'persistent_2'])
          expect(persistent_datastores['persistent_1'].name).to eq('persistent_1')
          expect(persistent_datastores['persistent_2'].name).to eq('persistent_2')
        end

        context 'when there are no datastores' do
          it 'initializes ephemeral and persistentto empty hashes' do
            allow(cloud_searcher).to receive(:get_properties).with('fake-datastore-name',
                                                           VimSdk::Vim::Datastore,
                                                           Datastore::PROPERTIES).and_return({})

            expect(cluster.ephemeral_datastores).to eq({})
            expect(cluster.persistent_datastores).to eq({})
          end
        end
      end

      describe 'cluster utilization' do
        context 'when we are using resource pools' do
          context 'when utilization data is available' do
            context 'when the runtime status is green' do
              let(:fake_runtime_info) do
                instance_double(
                  'VimSdk::Vim::ResourcePool::RuntimeInfo',
                  overall_status: 'green',
                  memory: instance_double(
                    'VimSdk::Vim::ResourcePool::ResourceUsage',
                    max_usage: 1024 * 1024 * 100,
                    overall_usage: 1024 * 1024 * 75,
                  )
                )
              end

              it 'sets resources to values in the runtime status' do
                expect(cluster.free_memory).to eq(25)
              end
            end

            context 'when the runtime status is not green (i.e. it is unreliable)' do
              it 'defaults resources to zero so that it is ignored' do
                expect(cluster.free_memory).to eq(0)
              end
            end
          end
        end

        context 'when we are using clusters directly' do
          def generate_host_property(mob, maintenance_mode, memory_size)
            {
              mob => {
                'runtime.inMaintenanceMode' => maintenance_mode ? 'true' : 'false',
                :obj => mob,
                'hardware.memorySize' => memory_size,
              }
            }
          end

          let(:inactive_host_properties) do
            {}.merge(
              generate_host_property(instance_double('VimSdk::Vim::ClusterComputeResource'), true, nil)
            ).merge(
              generate_host_property(instance_double('VimSdk::Vim::ClusterComputeResource'), true, nil)
            )
          end

          before do
            allow(cluster_config).to receive(:resource_pool).and_return(nil)
          end

          context 'when there are active host mobs' do
            let(:active_host_1_mob) { instance_double('VimSdk::Vim::ClusterComputeResource') }
            let(:active_host_2_mob) { instance_double('VimSdk::Vim::ClusterComputeResource') }
            let(:active_host_mobs) { [active_host_1_mob, active_host_2_mob] }

            before do
              hosts_properties = inactive_host_properties.merge(
                generate_host_property(active_host_1_mob, false, 100 * 1024 * 1024)
              ).merge(
                generate_host_property(active_host_2_mob, false, 40 * 1024 * 1024)
              )

              allow(cloud_searcher).to receive(:get_properties)
                               .with(cluster_hosts,
                                     VimSdk::Vim::HostSystem,
                                     described_class::HOST_PROPERTIES,
                                     ensure_all: true)
                               .and_return(hosts_properties)
            end

            before do
              performance_counters = {
                active_host_1_mob => {
                  'mem.usage.average' => '2500,2500',
                },
                active_host_2_mob => {
                  'mem.usage.average' => '7500,7500',
                },
              }

              allow(client).to receive(:get_perf_counters)
                               .with(active_host_mobs,
                                     described_class::HOST_COUNTERS,
                                     max_sample: 5)
                               .and_return(performance_counters)

            end

            it 'sets resources to values based on the active hosts in the cluster' do
              expect(cluster.free_memory).to eq(85)
            end
          end

          context 'when there are no active cluster hosts' do
            before do
              allow(cloud_searcher).to receive(:get_properties)
                               .with(cluster_hosts,
                                     VimSdk::Vim::HostSystem,
                                     described_class::HOST_PROPERTIES,
                                     ensure_all: true)
                               .and_return(inactive_host_properties)
            end

            it 'defaults free memory to zero' do
              expect(cluster.free_memory).to eq(0)
            end
          end
        end
      end
    end

    describe '#datacenter' do
      it 'returns the injected datacenter' do
        expect(subject.datacenter).to eq(datacenter)
      end
    end

    describe '#persistent' do
      context 'when a matching datastore is in the persistent datastore pool' do
        it 'returns that persistent datastore' do
          expect(cluster.persistent('persistent_1').name).to eq('persistent_1')
        end
      end

      context 'when no matching datastore is in the persistent pool' do
        it 'returns nil' do
          expect(cluster.persistent('nonexistent-datastore-name')).to be_nil
        end
      end
    end

    describe '#free_memory' do
      let(:fake_runtime_info) do
        instance_double(
          'VimSdk::Vim::ResourcePool::RuntimeInfo',
          overall_status: 'green',
          memory: instance_double(
            'VimSdk::Vim::ResourcePool::ResourceUsage',
            max_usage: 1024 * 1024 * 100,
            overall_usage: 1024 * 1024 * 75,
          )
        )
      end

      it 'returns the amount of free memory in the cluster' do
        expect(cluster.free_memory).to eq(25)
      end

      context 'when we fail to get the utilization for a resource pool' do
        before do
          allow(cloud_searcher).to receive(:get_properties)
                                     .with(fake_resource_pool_mob, VimSdk::Vim::ResourcePool, "summary")
                                     .and_return(nil)
        end

        it 'raises an exception' do
          expect { cluster.free_memory }.to raise_error("Failed to get utilization for resource pool #{fake_resource_pool}")
        end
      end
    end

    describe '#allocate' do
      let(:fake_runtime_info) do
        instance_double(
          'VimSdk::Vim::ResourcePool::RuntimeInfo',
          overall_status: 'green',
          memory: instance_double(
            'VimSdk::Vim::ResourcePool::ResourceUsage',
            max_usage: 1024 * 1024 * 100,
            overall_usage: 1024 * 1024 * 75,
          )
        )
      end

      it 'changes the amount of free memory in the cluster' do
        expect { cluster.allocate(5) }.to change { cluster.free_memory }.from(25).to(20)
      end
    end

    describe '#mob' do
      it 'returns the cluster mob' do
        expect(cluster.mob).to eq(cluster_mob)
      end
    end

    describe '#resource_pool' do
      it 'returns a resource pool object backed by the resource pool in the cloud properties' do
        expect(cluster.resource_pool).to eq(fake_resource_pool)
        expect(ResourcePool).to have_received(:new).with(client, logger, cluster_config, fake_resource_pool_mob)
      end
    end

    describe '#pick_persistent' do
      context 'when there are no persistent datastores' do
        let(:fake_datastore_properties) { {} }

        it 'raises a Bosh::Clouds::NoDiskSpace' do
          expect {
            cluster.pick_persistent(1)
          }.to raise_error(Bosh::Clouds::NoDiskSpace)
        end
      end

      context 'when there are persistent datastores' do
        it 'logs a bunch of debug info since it is really hard to know what happening otherwise' do
          cluster.pick_persistent(10001)

          expect(log_output.string).to include 'Looking for a persistent datastore in fake-cluster-name with 10001MB free space.'
          expect(log_output.string).to include 'All datastores: ["persistent_1 (10000MB free of 20000MB capacity)", "persistent_2 (20000MB free of 40000MB capacity)"]'
          expect(log_output.string).to include 'Datastores with enough space: ["persistent_2 (20000MB free of 40000MB capacity)"]'
        end

        context 'and there is more free space than the disk threshold' do
          it 'picks the datastore with preference to those with the most free space' do
            first_datastore = nil
            expect(Util).to receive(:weighted_random) do |datastore_weights|
              expect(datastore_weights.size).to eq(2)
              first_datastore, first_weight = datastore_weights.first
              expect(first_datastore.name).to eq('persistent_1')
              expect(first_weight).to eq(10000)

              second_datastore, second_weight = datastore_weights[1]
              expect(second_datastore.name).to eq('persistent_2')
              expect(second_weight).to eq(20000)

              first_datastore
            end
            expect(cluster.pick_persistent(10)).to eq(first_datastore)
          end
        end

        context 'and there is less persistent free space than the disk threshold' do
          it 'raises a Bosh::Clouds::NoDiskSpace' do
            expect {
              cluster.pick_persistent(20000 - (DISK_HEADROOM - 1))
            }.to raise_error do |error|
              expect(error).to be_an_instance_of(Bosh::Clouds::NoDiskSpace)
              expect(error.ok_to_retry).to be(true)
              expect(error.message).to eq(<<-MSG)
Couldn't find a persistent datastore with 18977MB of free space accessible from cluster 'fake-cluster-name'. Found:
 persistent_1 (10000MB free of 20000MB capacity)
 persistent_2 (20000MB free of 40000MB capacity)
MSG
            end
          end
        end
      end
    end

    describe '#pick_ephemeral' do
      context 'when there are no ephemeral datastores' do
        let(:fake_datastore_properties) { {} }

        it 'raises' do
          expect{
            cluster.pick_ephemeral(1)
          }.to raise_error Bosh::Clouds::NoDiskSpace
        end
      end

      context 'when there are ephemeral datastores' do
        context 'and there is more free space than the disk threshold' do
          it 'picks the datastore with preference to those with the most free space' do
            first_datastore = nil
            expect(Util).to receive(:weighted_random) do |datastore_weights|
              expect(datastore_weights.size).to eq(2)
              first_datastore, first_weight = datastore_weights.first
              expect(first_datastore.name).to eq('ephemeral_1')
              expect(first_weight).to eq(15000)

              second_datastore, second_weight = datastore_weights[1]
              expect(second_datastore.name).to eq('ephemeral_2')
              expect(second_weight).to eq(25000)

              first_datastore
            end

            expect(cluster.pick_ephemeral(10)).to eq(first_datastore)
          end
        end

        context 'and there is less ephemeral free space than the disk threshold' do
          it 'raises' do
            expect {
              cluster.pick_ephemeral(25000 - (DISK_HEADROOM - 1))
            }.to raise_error Bosh::Clouds::NoDiskSpace
          end
        end
      end
    end

    describe '#name' do
      it 'returns the name from the configuration' do
        expect(cluster.name).to eq('fake-cluster-name')
      end
    end

    describe '#inspect' do
      it 'returns the printable form' do
        expect(cluster.inspect).to eq("<Cluster: #{cluster_mob} / fake-cluster-name>")
      end
    end
  end
end
