require 'spec_helper'

module Bosh::Director::Disk
  describe PersistentDiskComparator do
    let(:client_factory) { instance_double(Bosh::Director::ConfigServer::ClientFactory) }
    let(:config_server_client) { instance_double(Bosh::Director::ConfigServer::EnabledClient) }

    before do
      allow(Bosh::Director::ConfigServer::ClientFactory).to receive(:create).and_return(client_factory)
      allow(client_factory).to receive(:create_client).and_return(config_server_client)
    end

    describe '#is_equal?' do
      context 'at least one disk is not of type PersistentDisk' do
        let(:disk) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', {'a' => {'b' => 'c'}}, 10) }

        context 'first pair is not a disk' do
          let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new('not_a_disk', nil) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk, nil) }

          it 'return false' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'second pair is not a disk' do
          let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk, nil) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new('not_a_disk', nil) }

          it 'return false' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end
      end

      context 'cloud_properties' do
        let(:disk_1) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', {'a' => {'b' => 'c'}}, 10) }
        let(:variable_set_1) { instance_double(Bosh::Director::Models::VariableSet) }
        let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_1, variable_set_1) }

        context 'when different' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', {'k' => {'l' => 'm'}}, 10) }
          let(:variable_set_2) { instance_double(Bosh::Director::Models::VariableSet) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set_2) }

          it 'returns false' do
            expect(config_server_client).to receive(:interpolate_with_versioning).with({'a' => {'b' => 'c'}}, variable_set_1).and_return({'a' => {'b' => 'c'}})
            expect(config_server_client).to receive(:interpolate_with_versioning).with({'k' => {'l' => 'm'}}, variable_set_2).and_return({'k' => {'l' => 'm'}})

            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'when same' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', {'a' => {'b' => 'c'}}, 10) }
          let(:variable_set_2) { instance_double(Bosh::Director::Models::VariableSet) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set_2) }

          it 'returns true' do
            expect(config_server_client).to receive(:interpolate_with_versioning).with({'a' => {'b' => 'c'}}, variable_set_1).and_return({'a' => {'b' => 'c'}})
            expect(config_server_client).to receive(:interpolate_with_versioning).with({'a' => {'b' => 'c'}}, variable_set_2).and_return({'a' => {'b' => 'c'}})

            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_truthy
          end
        end
      end

      context 'size' do
        let(:disk_1) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 10) }
        let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
        let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_1, variable_set) }
        let(:cloud_properties) { {'a' => {'b' => 'c'}} }

        before do
          allow(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, anything).and_return(cloud_properties)
        end

        context 'when different' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 20) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set) }

          it 'returns false' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'when same' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 10) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set) }

          it 'returns true' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_truthy
          end
        end
      end

      context 'name' do
        let(:disk_1) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, size) }
        let(:variable_set) { instance_double(Bosh::Director::Models::VariableSet) }
        let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_1, variable_set) }
        let(:cloud_properties) { {'a' => {'b' => 'c'}} }
        let(:size) { 10 }

        before do
          allow(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, anything).and_return(cloud_properties)
        end

        context 'when different' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('not_smurf', cloud_properties, size) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set) }

          it 'returns false' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'when same' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, size) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set) }

          it 'returns true' do
            expect(
              PersistentDiskComparator.new().is_equal?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_truthy
          end
        end
      end
    end

    describe '#size_diff_only?' do
      let(:disk_1) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 10) }
      let(:cloud_properties) { {'a' => {'b' => 'c'}} }
      let(:variable_set_1) { instance_double(Bosh::Director::Models::VariableSet) }
      let(:variable_set_2) { instance_double(Bosh::Director::Models::VariableSet) }

      let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_1, variable_set_1) }

      context 'at least one disk is not of type PersistentDisk' do
        let(:disk) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', {'a' => {'b' => 'c'}}, 10) }

        context 'first pair is not a disk' do
          let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new('not_a_disk', nil) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk, nil) }
          it 'return false' do
            expect(
              PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'second pair is not a disk' do
          let(:persistent_disk_variableset_pair_1) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk, nil) }
          let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new('not_a_disk', nil) }
          it 'return false' do
            expect(
              PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end
      end

      context 'when cloud_properties are different' do
        let(:other_cloud_properties) { {'k' => {'l' => 'm'}} }
        let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', other_cloud_properties, 10) }
        let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set_2) }

        it 'returns false' do
          expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, variable_set_1).and_return(cloud_properties)
          expect(config_server_client).to receive(:interpolate_with_versioning).with(other_cloud_properties, variable_set_2).and_return(other_cloud_properties)

          expect(
            PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
          ).to be_falsey
        end
      end

      context 'when names are different' do
        let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('not_smurf', cloud_properties, 10) }
        let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set_2) }

        before do
          allow(config_server_client).to receive(:interpolate_with_versioning).exactly(2).times.with(cloud_properties, anything).and_return(cloud_properties)
        end

        it 'returns false' do
          expect(
            PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
          ).to be_falsey
        end
      end

      context 'when cloud_properties and names are the same' do
        let(:persistent_disk_variableset_pair_2) { Bosh::Director::Disk::PersistentDiskVariableSetPair.new(disk_2, variable_set_2) }

        context 'when size is the same' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 10) }

          it 'returns false' do
            expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, variable_set_1).and_return(cloud_properties)
            expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, variable_set_2).and_return(cloud_properties)

            expect(
              PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_falsey
          end
        end

        context 'when size is different' do
          let(:disk_2) { Bosh::Director::DeploymentPlan::PersistentDiskCollection::PersistentDisk.new('smurf', cloud_properties, 20) }

          it 'returns true' do
            expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, variable_set_1).and_return(cloud_properties)
            expect(config_server_client).to receive(:interpolate_with_versioning).with(cloud_properties, variable_set_2).and_return(cloud_properties)

            expect(
              PersistentDiskComparator.new().size_diff_only?(persistent_disk_variableset_pair_1, persistent_disk_variableset_pair_2)
            ).to be_truthy
          end
        end
      end
    end
  end
end
