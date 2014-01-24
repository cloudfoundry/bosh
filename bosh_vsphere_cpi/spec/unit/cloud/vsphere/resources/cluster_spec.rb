require 'spec_helper'

class VSphereCloud::Resources
  describe Cluster do
    subject(:cluster) { described_class.new(cloud_config, cluster_config, properties) }

    let(:allow_mixed) { false }
    let(:cloud_config) do
      instance_double(
        'VSphereCloud::Config',
        datacenter_datastore_pattern: /eph/,
        datacenter_persistent_datastore_pattern: /persist/,
        datacenter_allow_mixed_datastores: allow_mixed,
        mem_overcommit: 1.0,
        logger: logger,
        client: client,
      )
    end
    let(:logger) { instance_double('Logger', debug: nil, warn: nil) }
    let(:client) { instance_double('VSphereCloud::Client') }

    let(:cluster_config) do
      instance_double(
        'VSphereCloud::ClusterConfig',
        name: 'fake-cluster-name',
        resource_pool: 'fake-resource-pool',
      )
    end

    let(:properties) do
      {
        'obj' => cluster_mob,
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

    let(:ephemeral_store_properties) { { 'name' => 'ephemeral_1' } }
    let(:fake_ephemeral_store_resource) { instance_double('VSphereCloud::Resources::Datastore', name: 'ephemeral_1', free_space: 15000) }
    let(:ephemeral_store_2_properties) { { 'name' => 'ephemeral_2' } }
    let(:fake_ephemeral_store_2_resource) { instance_double('VSphereCloud::Resources::Datastore', name: 'ephemeral_2', free_space: 25000) }
    let(:persistent_store_properties) { { 'name' => 'persistent_1' } }
    let(:fake_persistent_store_resource) { instance_double('VSphereCloud::Resources::Datastore', name: 'persistent_1', free_space: 10000) }
    let(:persistent_store_2_properties) { { 'name' => 'persistent_2' } }
    let(:fake_persistent_store_2_resource) { instance_double('VSphereCloud::Resources::Datastore', name: 'persistent_2', free_space: 20000) }
    let(:shared_store_properties) { { 'name' => 'persistent_and_ephemeral_1' } }
    let(:fake_shared_store_resource) {
      instance_double(
        'VSphereCloud::Resources::Datastore',
        name: 'persistent_and_ephemeral_1',
        free_space: 30000,
      )
    }
    let(:shared_store_2_properties) { { 'name' => 'persistent_and_ephemeral_2' } }
    let(:fake_shared_store_2_resource) {
      instance_double(
        'VSphereCloud::Resources::Datastore',
        name: 'persistent_and_ephemeral_2',
        free_space: 50000,
      )
    }

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

    before do
      allow(client).to receive(:get_properties)
                       .with('fake-datastore-name', VimSdk::Vim::Datastore, Datastore::PROPERTIES)
                       .and_return(fake_datastore_properties)
    end

    before do
      allow(Datastore).to receive(:new).with(ephemeral_store_properties).and_return(fake_ephemeral_store_resource)
      allow(Datastore).to receive(:new).with(ephemeral_store_2_properties).and_return(fake_ephemeral_store_2_resource)
      allow(Datastore).to receive(:new).with(persistent_store_properties).and_return(fake_persistent_store_resource)
      allow(Datastore).to receive(:new).with(persistent_store_2_properties).and_return(fake_persistent_store_2_resource)
      allow(Datastore).to receive(:new).with(shared_store_properties).and_return(fake_shared_store_resource)
      allow(Datastore).to receive(:new).with(shared_store_2_properties).and_return(fake_shared_store_2_resource)
    end

    before do
      allow(ResourcePool).to receive(:new)
                             .with(cloud_config, cluster_config, fake_resource_pool_mob)
                             .and_return(fake_resource_pool)
    end

    let(:fake_runtime_info) do
      instance_double(
        'VimSdk::Vim::ResourcePool::RuntimeInfo',
        overall_status: 'red',
      )
    end

    before do
      allow(client).to receive(:get_properties)
                       .with(fake_resource_pool_mob, VimSdk::Vim::ResourcePool, "summary")
                       .and_return({
                                     'summary' => instance_double(
                                       'VimSdk::Vim::ResourcePool::Summary',
                                       runtime: fake_runtime_info
                                     )
                                   })
    end

    describe '#initialize' do
      describe 'datastores' do
        it 'places each matching datastore in the appropriate array' do
          ephemeral_datastores = cluster.ephemeral_datastores
          expect(ephemeral_datastores.keys).to match_array(['ephemeral_1', 'ephemeral_2'])
          expect(ephemeral_datastores['ephemeral_1']).to eq(fake_ephemeral_store_resource)
          expect(ephemeral_datastores['ephemeral_2']).to eq(fake_ephemeral_store_2_resource)

          persistent_datastores = cluster.persistent_datastores
          expect(persistent_datastores.keys).to match_array(['persistent_1', 'persistent_2'])
          expect(persistent_datastores['persistent_1']).to eq(fake_persistent_store_resource)
          expect(persistent_datastores['persistent_2']).to eq(fake_persistent_store_2_resource)

          expect(cluster.shared_datastores).to eq({})
        end

        context 'when there is a datastore that matches ephemeral and persistent patterns' do
          before do
            fake_datastore_properties[fake_shared_store_resource] = shared_store_properties
          end

          context 'and allow mixed is disabled' do
            it 'raises an exception' do
              expect { cluster }.to raise_error(/Datastore patterns are not mutually exclusive/)
            end
          end

          context 'and allow mixed is enabled' do
            let(:allow_mixed) { true }

            it 'does not raise and puts them into shared datastores' do
              shared_datastores = cluster.shared_datastores
              expect(shared_datastores.keys).to eq(['persistent_and_ephemeral_1'])
              expect(shared_datastores['persistent_and_ephemeral_1']).to eq(fake_shared_store_resource)
            end
          end

        end

        context 'when there are no datastores' do
          it 'initializes ephemeral, persistent and shared to empty hashes' do
            allow(client).to receive(:get_properties).with('fake-datastore-name',
                                                           VimSdk::Vim::Datastore,
                                                           Datastore::PROPERTIES).and_return({})

            expect(cluster.ephemeral_datastores).to eq({})
            expect(cluster.persistent_datastores).to eq({})
            expect(cluster.shared_datastores).to eq({})
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

          context 'when we fail to get the utilization for a resource pool' do
            before do
              allow(client).to receive(:get_properties)
                               .with(fake_resource_pool_mob, VimSdk::Vim::ResourcePool, "summary")
                               .and_return(nil)
            end

            it "raises an exception" do
              expect { cluster }.to raise_error("Failed to get utilization for resource pool #{fake_resource_pool}")
            end
          end
        end

        context 'when we are using clusters directly' do
          def generate_host_property(mob, maintenance_mode, memory_size)
            {
              mob => {
                'runtime.inMaintenanceMode' => maintenance_mode ? 'true' : 'false',
                'obj' => mob,
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

              allow(client).to receive(:get_properties)
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
              allow(client).to receive(:get_properties)
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

    describe '#persistent' do
      context 'when a matching datastore is in the persistent datastore pool' do
        it 'returns that persistent datastore' do
          expect(cluster.persistent('persistent_1')).to eq(fake_persistent_store_resource)
        end
      end
      context 'when a matching datastore is in the shared datastore pool' do
        let(:allow_mixed) { true }

        before do
          fake_datastore_properties[fake_shared_store_resource] = shared_store_properties
        end

        it 'returns the shared datastore' do
          expect(cluster.persistent('persistent_and_ephemeral_1')).to eq(fake_shared_store_resource)
        end
      end

      context 'when a matching datastore is in neither pool' do
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
        expect(ResourcePool).to have_received(:new).with(cloud_config, cluster_config, fake_resource_pool_mob)
      end
    end

    describe '#pick_persistent' do
      context 'when there are no persistent datastores' do
        let(:fake_datastore_properties) { {} }

        context 'when there shared datastores' do
            let(:allow_mixed) { true }

            before do
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_properties
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_2_properties
            end

            context 'and there is more shared free space than the disk threshold' do
              it 'picks the shared datastore with preference to those with the most free space' do
                expect(Util).to receive(:weighted_random)
                                .with([[fake_shared_store_resource, 30000], [fake_shared_store_2_resource, 50000]])
                                .and_return(fake_shared_store_2_resource)

                picked_datastore = cluster.pick_persistent(20000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to eq(fake_shared_store_2_resource)
              end
            end

            context 'and there is less shared free space than the disk threshold' do
              it 'returns nil' do
                picked_datastore = cluster.pick_persistent(50000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to be_nil
              end
            end
          end

        context 'when there no shared datastores' do
          it 'returns nil' do
            picked_datastore = cluster.pick_persistent(1)
            expect(picked_datastore).to be_nil
          end
        end
      end

      context 'when there are persistent datastores' do
        context 'and there is more free space than the disk threshold' do
          it 'picks the datastore with preference to those with the most free space' do
            expect(Util).to receive(:weighted_random)
                            .with([[fake_persistent_store_resource, 10000], [fake_persistent_store_2_resource, 20000]])
                            .and_return(fake_persistent_store_2_resource)

            expect(cluster.pick_persistent(10)).to eq(fake_persistent_store_2_resource)
          end
        end

        context 'and there is less persistent free space than the disk threshold' do
          context 'when there shared datastores' do
            let(:allow_mixed) { true }

            before do
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_properties
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_2_properties
            end

            context 'and there is more shared free space than the disk threshold' do
              it 'picks the shared datastore with preference to those with the most free space' do
                expect(Util).to receive(:weighted_random)
                                .with([[fake_shared_store_resource, 30000], [fake_shared_store_2_resource, 50000]])
                                .and_return(fake_shared_store_2_resource)

                picked_datastore = cluster.pick_persistent(20000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to eq(fake_shared_store_2_resource)
              end
            end

            context 'and there is less shared free space than the disk threshold' do
              it 'returns nil' do
                picked_datastore = cluster.pick_persistent(50000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to be_nil
              end
            end
          end

          context 'when there no shared datastores' do
            it 'returns nil' do
              picked_datastore = cluster.pick_persistent(20000 - (DISK_THRESHOLD - 1))
              expect(picked_datastore).to be_nil
            end
          end
        end
      end
    end

    describe '#pick_ephemeral' do
      context 'when there are no ephemeral datastores' do
        let(:fake_datastore_properties) { {} }

        context 'when there shared datastores' do
          let(:allow_mixed) { true }

          before do
            fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_properties
            fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_2_properties
          end

          context 'and there is more shared free space than the disk threshold' do
            it 'picks the shared datastore with preference to those with the most free space' do
              expect(Util).to receive(:weighted_random)
                              .with([[fake_shared_store_resource, 30000], [fake_shared_store_2_resource, 50000]])
                              .and_return(fake_shared_store_2_resource)

              picked_datastore = cluster.pick_ephemeral(25000 - (DISK_THRESHOLD - 1))
              expect(picked_datastore).to eq(fake_shared_store_2_resource)
            end
          end

          context 'and there is less shared free space than the disk threshold' do
            it 'returns nil' do
              picked_datastore = cluster.pick_ephemeral(50000 - (DISK_THRESHOLD - 1))
              expect(picked_datastore).to be_nil
            end
          end
        end

        context 'when there no shared datastores' do
          it 'returns nil' do
            picked_datastore = cluster.pick_ephemeral(1)
            expect(picked_datastore).to be_nil
          end
        end
      end

      context 'when there are ephemeral datastores' do
        context 'and there is more free space than the disk threshold' do
          it 'picks the datastore with preference to those with the most free space' do
            expect(Util).to receive(:weighted_random)
                            .with([[fake_ephemeral_store_resource, 15000], [fake_ephemeral_store_2_resource, 25000]])
                            .and_return(fake_ephemeral_store_2_resource)

            expect(cluster.pick_ephemeral(10)).to eq(fake_ephemeral_store_2_resource)
          end
        end

        context 'and there is less ephemeral free space than the disk threshold' do
          context 'when there shared datastores' do
            let(:allow_mixed) { true }

            before do
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_properties
              fake_datastore_properties[instance_double('VimSdk::Vim::Datastore')] = shared_store_2_properties
            end

            context 'and there is more shared free space than the disk threshold' do
              it 'picks the shared datastore with preference to those with the most free space' do
                expect(Util).to receive(:weighted_random)
                                .with([[fake_shared_store_resource, 30000], [fake_shared_store_2_resource, 50000]])
                                .and_return(fake_shared_store_2_resource)

                picked_datastore = cluster.pick_ephemeral(25000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to eq(fake_shared_store_2_resource)
              end
            end

            context 'and there is less shared free space than the disk threshold' do
              it 'returns nil' do
                picked_datastore = cluster.pick_ephemeral(50000 - (DISK_THRESHOLD - 1))
                expect(picked_datastore).to be_nil
              end
            end
          end

          context 'when there no shared datastores' do
            it 'returns nil' do
              picked_datastore = cluster.pick_ephemeral(25000 - (DISK_THRESHOLD - 1))
              expect(picked_datastore).to be_nil
            end
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
