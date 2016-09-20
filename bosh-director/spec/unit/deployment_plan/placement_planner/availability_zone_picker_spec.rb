require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::AvailabilityZonePicker do
    subject(:zone_picker) { PlacementPlanner::AvailabilityZonePicker.new(instance_plan_factory, network_planner, job_networks, desired_azs) }
    let(:network_planner) { NetworkPlanner::Planner.new(logger) }
    let(:network_reservation_repository) { BD::DeploymentPlan::NetworkReservationRepository.new(instance_double(Bosh::Director::DeploymentPlan::Planner), logger) }
    let(:skip_drain_decider) { SkipDrain.new(true) }
    let(:instance_plan_factory) { InstancePlanFactory.new(instance_repo, {}, skip_drain_decider, index_assigner, network_reservation_repository) }
    let(:index_assigner) { PlacementPlanner::IndexAssigner.new(deployment_model) }
    let(:deployment_model) { Bosh::Director::Models::Deployment.make }
    let(:deployment_subnets) do
      [
        ManualNetworkSubnet.new(
          'network_A',
          NetAddr::CIDR.create('192.168.1.0/24'),
          nil, nil, nil, nil, ['zone_1'], [],
          ['192.168.1.10', '192.168.1.11', '192.168.1.12', '192.168.1.13', '192.168.1.14'])
      ]
    end
    let(:deployment_network) { ManualNetwork.new('network_A', deployment_subnets, nil) }
    let(:job_networks) { [JobNetwork.new('network_A', nil, [], deployment_network)] }

    # we don't care about instances in this test, it is hard to make them, because they need deployment plan
    let(:instance_repo) do
      instance_double(InstanceRepository,
        fetch_existing: instance_double(Instance, update_description: nil, model: Bosh::Director::Models::Instance.make),
        fetch_obsolete_existing: instance_double(Instance, update_description: nil, model: Bosh::Director::Models::Instance.make),
        create: instance_double(Instance, model: Bosh::Director::Models::Instance.make)
      )
    end
    let(:az1) { AvailabilityZone.new('1', {}) }
    let(:az2) { AvailabilityZone.new('2', {}) }
    let(:az3) { AvailabilityZone.new('3', {}) }

    let(:deployment) { nil }
    let(:job) { instance_double(InstanceGroup, name: 'fake-job') }

    def desired_instance(zone = nil)
      DesiredInstance.new(job, deployment, zone, 0)
    end

    def existing_instance_with_az(index, az, persistent_disks=[])
      instance_model = Bosh::Director::Models::Instance.make(index: index, availability_zone: az, deployment: deployment_model)
      allow(instance_model).to receive(:persistent_disks).and_return(persistent_disks)
      instance_model
    end
    let(:desired_azs) { [] }

    describe 'placing and matching' do
      it 'a job in no zones with 3 instances, we expect two existing instances are reused and one new instance' do
        unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]
        existing_0 = existing_instance_with_az(0, nil)
        existing_1 = existing_instance_with_az(1, nil)
        unmatched_existing_instances = [existing_0, existing_1]

        results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
        existing = results.select(&:existing?)
        expect(existing.size).to eq(2)
        expect(existing[0].existing_instance).to eq(existing_0)
        expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
        expect(existing[1].existing_instance).to eq(existing_1)
        expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])

        expect(results.select(&:new?).map(&:desired_instance)).to match_array([unmatched_desired_instances[2]])
        expect(results.select(&:obsolete?)).to eq([])
      end

      context 'when a job in nil zones with 3 instances' do
        let(:desired_azs) { nil }

        it 'we expect two existing instances are reused and one new instance' do
          unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]
          existing_0 = existing_instance_with_az(0, nil, ['disk-blah'])
          existing_1 = existing_instance_with_az(1, nil)
          unmatched_existing_instances = [existing_0, existing_1]

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          existing = results.select(&:existing?)
          expect(existing.size).to eq(2)
          expect(existing[0].existing_instance).to eq(existing_0)
          expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
          expect(existing[1].existing_instance).to eq(existing_1)
          expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])

          expect(results.select(&:new?).map(&:desired_instance)).to match_array([unmatched_desired_instances[2]])
          expect(results.select(&:obsolete?)).to eq([])
        end
      end

      context 'when a job in 2 zones with 3 instances' do
        let(:desired_azs) { [az1, az2] }

        it 'we expect all instances will be new' do
          unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]
          unmatched_existing_instances = []

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          expect(results.select(&:existing?)).to eq([])

          new_plans = results.select(&:new?)
          expect(new_plans.size).to eq(3)
          expect(new_plans[0].desired_instance).to eq(desired_instance(az1))
          expect(new_plans[1].desired_instance).to eq(desired_instance(az2))
          expect(new_plans[2].desired_instance).to eq(desired_instance(az1))

          expect(results.select(&:obsolete?)).to eq([])
        end
      end

      describe 'scaling down' do
        it 'prefers lower indexed existing instances' do
          unmatched_desired_instances = [desired_instance]
          existing_0 = existing_instance_with_az(0, nil)
          existing_1 = existing_instance_with_az(1, nil)
          unmatched_existing_instances = [existing_1, existing_0]

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          expect(results.select(&:new?)).to eq([])

          existing = results.select(&:existing?)
          expect(existing.size).to eq(1)
          expect(existing[0].existing_instance).to eq(existing_0)
          expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])

          expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_1])
        end
      end

      describe 'when a job is deployed in 2 zones with 3 existing instances, and re-deployed into one zone' do
        let(:desired_azs) { [az1] }

        it 'should match the 2 existing instances from the desired zone to 2 of the desired instances' do
          unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]

          existing_zone1_2 = existing_instance_with_az(2, '1')
          existing_zone1_0 = existing_instance_with_az(0, '1')
          existing_zone2_1 = existing_instance_with_az(1, '2')
          unmatched_existing_instances = [existing_zone1_0, existing_zone1_2, existing_zone2_1]

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az1)])

          existing = results.select(&:existing?)
          expect(existing.size).to eq(2)
          expect(existing[0].existing_instance).to eq(existing_zone1_0)
          expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
          expect(existing[1].existing_instance).to eq(existing_zone1_2)
          expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])

          expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone2_1])
        end
      end

      describe 'when a job is deployed in 2 zones with 5 existing instances, and re-deployed into 3 zones' do
        let(:desired_azs) { [az1, az2, az3] }

        it 'should match the 2 existing instances from the 2 desired zones' do
          unmatched_desired_instances = [
            desired_instance,
            desired_instance,
            desired_instance,
            desired_instance,
            desired_instance,
          ]

          existing_zone1_0 = existing_instance_with_az(0, '1')
          existing_zone1_1 = existing_instance_with_az(1, '1')
          existing_zone1_2 = existing_instance_with_az(2, '1')
          existing_zone2_3 = existing_instance_with_az(3, '2')
          existing_zone2_4 = existing_instance_with_az(4, '2')

          unmatched_existing_instances = [existing_zone1_0, existing_zone1_1, existing_zone1_2, existing_zone2_3, existing_zone2_4]

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az3)])

          existing = results.select(&:existing?)
          expect(existing.size).to eq(4)
          expect(existing[0].existing_instance).to eq(existing_zone1_0)
          expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
          expect(existing[1].existing_instance).to eq(existing_zone2_3)
          expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])
          expect(existing[2].existing_instance).to eq(existing_zone1_1)
          expect(existing[2].desired_instance).to eq(unmatched_desired_instances[3])
          expect(existing[3].existing_instance).to eq(existing_zone2_4)
          expect(existing[3].desired_instance).to eq(unmatched_desired_instances[4])

          expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone1_2])
        end
      end

      describe 'when a job is deployed in 2 zones with 3 existing instances, and re-deployed into 3 zones with 4 instances' do
        let(:desired_azs) { [az1, az2, az3] }

        it 'uses the zone with 2 existing instances as the zone with the extra instance' do
          unmatched_desired_instances = [
            desired_instance,
            desired_instance,
            desired_instance,
            desired_instance,
          ]

          existing_zone1_0 = existing_instance_with_az(0, '1')
          existing_zone2_0 = existing_instance_with_az(1, '2')
          existing_zone2_2 = existing_instance_with_az(2, '2')

          unmatched_existing_instances = [existing_zone1_0, existing_zone2_0, existing_zone2_2]

          results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
          expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az3)])

          existing = results.select(&:existing?)
          expect(existing.size).to eq(3)
          expect(existing[0].existing_instance).to eq(existing_zone2_0)
          expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
          expect(existing[1].existing_instance).to eq(existing_zone1_0)
          expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])
          expect(existing[2].existing_instance).to eq(existing_zone2_2)
          expect(existing[2].desired_instance).to eq(unmatched_desired_instances[3])

          expect(results.select(&:obsolete?)).to eq([])
        end
      end

      describe 'when existing instances have persistent disk' do
        describe 'when existing instances have no az, and desired have no azs' do
          let(:desired_azs) { [] }
          it 'should not recreate the instances' do
            existing_0 = existing_instance_with_az(0, nil, [Bosh::Director::Models::PersistentDisk.make])
            unmatched_desired_instances = [desired_instance, desired_instance]
            results = zone_picker.place_and_match_in(unmatched_desired_instances, [existing_0])
            expect(results.select(&:new?).map(&:desired_instance)).to eq([unmatched_desired_instances[1]])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(1)
            expect(existing[0].existing_instance).to eq(existing_0)
            expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])

            expect(results.select(&:obsolete?)).to eq([])
          end
        end

        describe 'with the same number of desired instances both in the same zone' do
          let(:desired_azs) { [az1, az2] }

          it 'should not move existing instances' do
            existing_zone1_0 = existing_instance_with_az(0, '1', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone1_1 = existing_instance_with_az(1, '1', [Bosh::Director::Models::PersistentDisk.make])

            desired_instances = [desired_instance, desired_instance]
            results = zone_picker.place_and_match_in(desired_instances, [existing_zone1_0, existing_zone1_1])
            expect(results.select(&:new?)).to eq([])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(2)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[0].desired_instance).to eq(desired_instances[0])
            expect(existing[1].existing_instance).to eq(existing_zone1_1)
            expect(existing[1].desired_instance).to eq(desired_instances[1])

            expect(results.select(&:obsolete?)).to eq([])
          end
        end

        describe 'when the existing instance is not in the set of desired azs' do
          let(:desired_azs) { [az1, az2] }

          it 'should not reuse the existing instance' do
            unmatched_desired_instances = [desired_instance, desired_instance]

            existing_zone1_0 = existing_instance_with_az(0, '1', ['disk0'])
            existing_zone66_1 = existing_instance_with_az(1, '66', ['disk1'])
            unmatched_existing_instances = [existing_zone1_0, existing_zone66_1]

            results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
            expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az2)])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(1)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[0].desired_instance).to eq(unmatched_desired_instances[1])

            expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone66_1])
          end
        end

        describe "when none of instances' persistent disks are active" do
          let(:desired_azs) { [az1, az2] }

          it 'should not destroy/remove/re-balance them, should do nothing' do
            existing_zone1_0 = existing_instance_with_az(0, '1', [Bosh::Director::Models::PersistentDisk.make(active: false)])
            existing_zone1_1 = existing_instance_with_az(1, '1', [Bosh::Director::Models::PersistentDisk.make(active: false)])

            unmatched_desired_instances = [desired_instance, desired_instance]
            results = zone_picker.place_and_match_in(unmatched_desired_instances, [existing_zone1_0, existing_zone1_1])
            expect(results.select(&:new?)).to eq([])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(2)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])
            expect(existing[1].existing_instance).to eq(existing_zone1_1)
            expect(existing[1].desired_instance).to eq(unmatched_desired_instances[1])

            expect(results.select(&:obsolete?)).to eq([])
          end
        end

        describe 'and some existing instances have no persistent disks' do
          let(:desired_azs) { [az1, az2] }

          it 'should re-balance the instance that never had persistent disk' do
            existing_zone1_0 = existing_instance_with_az(0, '1')
            existing_zone1_1 = existing_instance_with_az(1, '1', [Bosh::Director::Models::PersistentDisk.make(active: false)])

            unmatched_desired_instances = [desired_instance, desired_instance]
            results = zone_picker.place_and_match_in(unmatched_desired_instances, [existing_zone1_0, existing_zone1_1])
            expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az2)])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(1)
            expect(existing[0].existing_instance).to eq(existing_zone1_1)
            expect(existing[0].desired_instance).to eq(unmatched_desired_instances[1])

            expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone1_0])
          end
        end

        describe 'where 2 or more existing instances in the same AZ with persistent disk and scale down to 1' do
          let(:desired_azs) { [az1] }

          it 'should eliminate one of the instances' do
            existing_zone1_0 = existing_instance_with_az(0, '1', [Bosh::Director::Models::PersistentDisk.make(active: true)])
            existing_zone1_1 = existing_instance_with_az(1, '1', [Bosh::Director::Models::PersistentDisk.make(active: false)])

            unmatched_desired_instances = [desired_instance]
            unmatched_existing_instances = [existing_zone1_0, existing_zone1_1]

            results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
            expect(results.select(&:new?)).to eq([])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(1)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[0].desired_instance).to eq(unmatched_desired_instances[0])

            expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone1_1])
          end
        end

        describe 'when an az that has instances with persistent disks is removed' do
          let(:desired_azs) { [az1, az2] }

          it 'should re-balance the instances across the remaining azs' do
            existing_zone1_0 = existing_instance_with_az(0, '1', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone1_1 = existing_instance_with_az(1, '1', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone2_2 = existing_instance_with_az(2, '2', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone2_3 = existing_instance_with_az(3, '2', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone3_4 = existing_instance_with_az(4, '3', [Bosh::Director::Models::PersistentDisk.make])
            existing_zone3_5 = existing_instance_with_az(5, '3', [Bosh::Director::Models::PersistentDisk.make])

            unmatched_desired_instances = [desired_instance, desired_instance, desired_instance, desired_instance, desired_instance, desired_instance]
            unmatched_existing_instances = [existing_zone1_0, existing_zone1_1, existing_zone2_2, existing_zone2_3, existing_zone3_4, existing_zone3_5]
            results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
            expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az1), desired_instance(az2)])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(4)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[1].existing_instance).to eq(existing_zone1_1)
            expect(existing[2].existing_instance).to eq(existing_zone2_2)
            expect(existing[3].existing_instance).to eq(existing_zone2_3)

            expect(results.select(&:obsolete?).map(&:existing_instance)).to eq([existing_zone3_4, existing_zone3_5])
          end
        end

        describe 'with one additional desired instance' do
          let(:desired_azs) { [az1, az2] }

          it 'should add the instance to the additional az' do
            unmatched_desired_instances = [desired_instance, desired_instance, desired_instance]

            existing_zone1_0 = existing_instance_with_az(0, '1', ['disk0'])
            existing_zone1_1 = existing_instance_with_az(1, '1', ['disk1'])
            unmatched_existing_instances = [existing_zone1_0, existing_zone1_1]

            results = zone_picker.place_and_match_in(unmatched_desired_instances, unmatched_existing_instances)
            expect(results.select(&:new?).map(&:desired_instance)).to eq([desired_instance(az2)])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(2)
            expect(existing[0].existing_instance).to eq(existing_zone1_0)
            expect(existing[1].existing_instance).to eq(existing_zone1_1)

            expect(results.select(&:obsolete?)).to eq([])
          end
        end
      end

      describe 'when some existing instances have ignore flag as true' do

        describe 'when removing an az that has ignored instances' do
          let(:desired_azs) { [az2] }

          it 'should raise' do
            existing_0 = existing_instance_with_az(0, az1.name, [])
            Bosh::Director::Models::IpAddress.make(instance_id: existing_0.id, task_id: "my-ip-address-task-id", address: 1234567890, network_name: "network_A")
            existing_0.update(ignore: true)
            expect {
              zone_picker.place_and_match_in([desired_instance], [existing_0])
            }.to raise_error Bosh::Director::DeploymentIgnoredInstancesModification, "Instance Group '#{existing_0.job}' no longer contains AZs [\"1\"] where ignored instance(s) exist."
          end
        end

        describe 'when adding/removing networks for instance groups with ignored vms' do
          it 'should raise' do
            existing_0 = existing_instance_with_az(0, az1.name, [])
            Bosh::Director::Models::IpAddress.make(instance_id: existing_0.id, task_id: "my-ip-address-task-id", address: 1234567890, network_name: "old-network")
            existing_0.update(ignore: true)
            expect {
              zone_picker.place_and_match_in([desired_instance], [existing_0])
            }.to raise_error Bosh::Director::DeploymentIgnoredInstancesModification, "In instance group '#{existing_0.job}', which contains ignored vms, an attempt was made to modify the networks. This operation is not allowed."
          end
        end

        describe 'when not using AZs and keeping enough desired instances' do
          let(:desired_azs) { nil }

          it 'should place and match existing instances' do
            existing_0 = existing_instance_with_az(0, nil, [])
            existing_0.update(ignore: true)
            Bosh::Director::Models::IpAddress.make(instance_id: existing_0.id, task_id: "my-ip-address-task-id", address: 1234567890, network_name: "network_A")
            results = zone_picker.place_and_match_in([desired_instance], [existing_0])

            existing = results.select(&:existing?)
            expect(existing.size).to eq(1)
            expect(existing[0].existing_instance).to eq(existing_0)

            expect(results.select(&:new?)).to be_empty
            expect(results.select(&:obsolete?)).to eq([])
          end
        end

        describe 'when the desired instance count drops below the number of ignored instances' do
          let(:desired_azs) { nil }
          it 'should raise' do
            existing_0 = existing_instance_with_az(0, nil, [])
            existing_0.update(ignore: true)
            Bosh::Director::Models::IpAddress.make(instance_id: existing_0.id, task_id: "my-ip-address-task-id", address: 1234567890, network_name: "network_A")

            desired_instances = []
            expect {
              zone_picker.place_and_match_in(desired_instances, [existing_0])
            }.to raise_error Bosh::Director::DeploymentIgnoredInstancesModification,
                             "Instance Group '#{existing_0.job}' has 1 ignored instance(s). 0 instance(s) of that " +
                                 "instance group were requested. Deleting ignored instances is not allowed."
          end
        end

        describe 'when lowering instance count to the number of ignored instances and all ignored instances are in the same az' do
          let(:desired_azs) { [az1,az2] }
          it 'should not rebalance ignored instances' do
            existing_zone1_0 = existing_instance_with_az(0, '1')
            existing_zone1_1 = existing_instance_with_az(1, '1')
            existing_zone2_2 = existing_instance_with_az(2, '2')
            existing_zone2_3 = existing_instance_with_az(3, '2')

            Bosh::Director::Models::IpAddress.make(instance_id: existing_zone1_0.id, task_id: "my-ip-address-task-id", address: 1234567890, network_name: "network_A")
            Bosh::Director::Models::IpAddress.make(instance_id: existing_zone1_1.id, task_id: "my-ip-address-task-id", address: 1234567891, network_name: "network_A")

            existing_zone1_0.update(ignore: true)
            existing_zone1_1.update(ignore: true)

            existing_instances = [existing_zone1_0, existing_zone1_1, existing_zone2_2, existing_zone2_3]

            results = zone_picker.place_and_match_in([desired_instance, desired_instance], existing_instances)
            existing = results.select(&:existing?)
            expect(results.size).to eq(4)
            expect(existing.size).to eq(2)

            obsoletes = results.select(&:obsolete?)
            expect(obsoletes.map(&:existing_instance)).to match_array([existing_zone2_2, existing_zone2_3])
          end
        end
      end
    end
  end
end
