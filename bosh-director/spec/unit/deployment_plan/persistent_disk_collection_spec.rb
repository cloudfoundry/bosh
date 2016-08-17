require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe PersistentDiskCollection do
      let(:persistent_disk_collection) { PersistentDiskCollection.new(logger) }
      let(:disk_size) { 30 }
      let(:cloud_properties) { {} }
      let(:disk_type) { DiskType.new('disk_name', disk_size, cloud_properties) }

      describe '#add_by_disk_size' do
        it 'adds disk given a disk size' do
          persistent_disk_collection.add_by_disk_size(30)

          disk_spec = persistent_disk_collection.generate_spec
          expect(disk_spec['persistent_disk']).to eq(30)
        end

        context 'when adding multiple disks' do
          it 'complains' do
            persistent_disk_collection.add_by_disk_size(30)

            expect {
              persistent_disk_collection.add_by_disk_size(300)
            }.to raise_error

            expect {
              persistent_disk_collection.add_by_disk_type(disk_type)
            }.to raise_error
          end
        end

        context 'when given a disk_size of 0' do
          it 'does not add disk to collection' do
            persistent_disk_collection.add_by_disk_size(0)

            expect(persistent_disk_collection.generate_spec).to eq( { 'persistent_disk' => 0 } )
          end
        end
      end

      describe '#add_by_disk_type' do
        it 'adds disk given a disk type' do
          persistent_disk_collection.add_by_disk_type(disk_type)

          disk_spec = persistent_disk_collection.generate_spec
          expect(disk_spec['persistent_disk']).to eq(30)
        end

        context 'when adding multiple disks' do
          it 'complains' do
            persistent_disk_collection.add_by_disk_type(disk_type)

            expect {
              persistent_disk_collection.add_by_disk_type(disk_type)
            }.to raise_error

            expect {
              persistent_disk_collection.add_by_disk_size(300)
            }.to raise_error
          end
        end
      end

      describe '#add_by_disk_name_and_type' do
        it 'adds multiple disks given disk name and type' do
          persistent_disk_collection.add_by_disk_name_and_type('first_disk', disk_type)
          persistent_disk_collection.add_by_disk_name_and_type('another_disk', disk_type)

          expect(persistent_disk_collection.collection[0].size).to eq(30)
          expect(persistent_disk_collection.collection[0].name).to eq('first_disk')

          expect(persistent_disk_collection.collection[1].size).to eq(30)
          expect(persistent_disk_collection.collection[1].name).to eq('another_disk')
        end

        context 'a legacy disk has already been added' do
          before do
            persistent_disk_collection.add_by_disk_size(disk_size)
          end

          it 'raises' do
            expect{ persistent_disk_collection.add_by_disk_name_and_type('another_disk', disk_type) }.to raise_error
          end
        end
      end

      describe '#needs_disk?' do
        context 'when using a single disk' do
          context 'when there are no disks' do
            it 'returns false' do
              expect(persistent_disk_collection.needs_disk?).to be(false)
            end
          end

          context 'when there is at least one disk' do
            before do
              persistent_disk_collection.add_by_disk_type(disk_type)
            end

            context 'when disk size is 0' do
              let(:disk_type) { DiskType.new('disk_name', 0, {'empty' => 'cloud'}) }

              it 'returns false' do
                expect(persistent_disk_collection.needs_disk?).to be(false)
              end
            end

            context 'when disk size is greater than 0' do
              it 'returns true' do
                expect(persistent_disk_collection.needs_disk?).to be(true)
              end
            end
          end
        end

        context 'when using multiple disks' do
          context 'when there are no disks' do
            it 'returns false' do
              expect(persistent_disk_collection.needs_disk?).to be(false)
            end
          end

          context 'when there is at least 1 disk' do
            before do
              persistent_disk_collection.add_by_disk_name_and_type('my-disk', disk_type)
              persistent_disk_collection.add_by_disk_name_and_type('another-disk', disk_type)
            end

            it 'returns true' do
              expect(persistent_disk_collection.needs_disk?).to be(true)
            end
          end
        end
      end

      describe '#is_different_from' do
        let(:old_persistent_disk_collection) { PersistentDiskCollection.new(logger) }

        before do
          persistent_disk_models.each do |disk|
            old_persistent_disk_collection.add_by_model(disk)
          end
        end

        context 'when using a single disk' do
          let(:persistent_disk_models) { [] }

          context 'when there are no disks in the persistent disk collection' do
            context 'when deployment has no disks' do
              it 'returns false' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(false)
              end
            end

            context 'when deployment has disks' do
              let(:persistent_disk_models) { [Models::PersistentDisk.make(size: 3)] }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end

              it 'logs' do
                expect(logger).to receive(:debug).with('Persistent disk removed: size 3, cloud_properties: {}')

                persistent_disk_collection.is_different_from(old_persistent_disk_collection)
              end
            end
          end

          context 'when there is one disk in the persistent disk collection' do
            before do
              persistent_disk_collection.add_by_disk_type(disk_type)
            end

            context 'when deployment has no disks' do
              let(:persistent_disk_models) { [] }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end
            end

            context 'when deployment has one disk' do
              let(:persistent_disk_models) do
                [Models::PersistentDisk.make(size: 30, cloud_properties: {})]
              end

              context 'when disks are the same' do
                it 'returns false' do
                  expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(false)
                end
              end

              context 'when disk sizes are different' do
                let(:disk_size) { 4 }

                it 'returns true' do
                  expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
                end
              end

              context 'when disk cloud properties are different' do
                let(:cloud_properties) { {'some' => 'cloud'} }

                it 'returns true' do
                  expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
                end

                it 'logs' do
                  expect(logger).to receive(:debug).with('Persistent disk changed: cloud_properties FROM {} TO {"some"=>"cloud"}')

                  persistent_disk_collection.is_different_from(old_persistent_disk_collection)
                end
              end
            end
          end
        end

        context 'when using multiple disks' do
          before do
            persistent_disk_collection.add_by_disk_name_and_type('disk1', disk_type)
            persistent_disk_collection.add_by_disk_name_and_type('disk2', disk_type)
          end

          context 'when deployment has one legacy disk' do
            let(:persistent_disk_models) { [
              Models::PersistentDisk.make(size: 3)
            ] }
            it 'returns true' do
              expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
            end
          end

          context 'when deployment has many disks' do
            let(:disk_size) { 3 }

            let(:persistent_disk_models) { [
              Models::PersistentDisk.make(name: 'disk2', size: 3),
              Models::PersistentDisk.make(name: 'disk1', size: 3),
            ] }

            context 'when all disks are equal' do
              it 'returns false' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(false)
              end
            end

            context 'when number of disks is different' do
              before do
                persistent_disk_collection.add_by_disk_name_and_type('disk3', disk_type)
              end

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end
            end

            context 'when there is a disk with size disagreement' do
              let(:disk_size) { 4 }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end
            end

            context 'when there is a disk with cloud config disagreement' do
              let(:cloud_properties) { { 'a' => 'b' } }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end
            end

            context 'when there is a disk with name disagreement' do
              let(:persistent_disk_models) { [
                Models::PersistentDisk.make(name: 'disk13', size: 3),
                Models::PersistentDisk.make(name: 'disk2', size: 3),
              ] }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(old_persistent_disk_collection)).to be(true)
              end
            end
          end
        end
      end

      describe '#changed_disk_pairs' do
        let(:desired_disks) { PersistentDiskCollection.new(logger) }
        let(:existing_disks) { PersistentDiskCollection.new(logger) }
        let(:subject) { desired_disks.changed_disk_pairs(existing_disks) }

        context 'unchanged' do
          context 'disk ordering unchanged' do
            it 'is not affected' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))
              desired_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))

              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))
              existing_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(0)
            end
          end

          context 'disk ordering changed' do
            it 'is not affected' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))
              desired_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))

              existing_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))
              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(0)
            end
          end
        end

        context 'disk removal' do
          context 'single disk' do
            it 'lists the change' do
              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(1)

              expect(subject[0][:new]).to be_nil
              expect(subject[0][:old].name).to eq('persistent1')
            end
          end

          context 'multiple disks' do
            it 'lists the change' do
              desired_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {'property' => 'one'}))

              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))
              existing_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))
              existing_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(2)

              expect(subject[0][:new]).to be_nil
              expect(subject[0][:old].name).to eq('persistent1')

              expect(subject[1][:new]).to be_nil
              expect(subject[1][:old].name).to eq('persistent2')
            end
          end
        end

        context 'disk added' do
          context 'single disk' do
            it 'lists the change' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(1)

              expect(subject[0][:new].size).to eq(3)
              expect(subject[0][:new].name).to eq('persistent1')
              expect(subject[0][:new].cloud_properties).to eq({'property' => 'one'})
              expect(subject[0][:old]).to be_nil
            end
          end

          context 'multiple disks' do
            it 'lists the change' do
              existing_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {'property' => 'one'}))

              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))
              desired_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {'property' => 'one'}))
              desired_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(2)

              expect(subject[0][:new].name).to eq('persistent1')
              expect(subject[0][:old]).to be_nil

              expect(subject[1][:new].name).to eq('persistent2')
              expect(subject[1][:old]).to be_nil
            end
          end
        end

        context 'disk modified' do
          context 'single disk changes size' do
            it 'lists the change' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk2', 6, {}))

              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {}))

              expect(subject.length).to eq(1)

              expect(subject[0][:new].size).to eq(6)
              expect(subject[0][:old].size).to eq(3)
            end
          end

          context 'single disk changes cloud_properties' do
            it 'lists the change' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk2', 3, {'property' => 'two'}))

              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {'property' => 'one'}))

              expect(subject.length).to eq(1)

              expect(subject[0][:new].cloud_properties).to eq({'property' => 'two'})
              expect(subject[0][:old].cloud_properties).to eq({'property' => 'one'})
            end
          end

          context 'multiple disks' do
            it 'lists the change' do
              desired_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 6, {}))
              desired_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 12, {}))
              desired_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {}))

              existing_disks.add_by_disk_name_and_type('persistent1', DiskType.new('disk1', 3, {}))
              existing_disks.add_by_disk_name_and_type('persistent2', DiskType.new('disk1', 3, {}))
              existing_disks.add_by_disk_name_and_type('persistent3', DiskType.new('disk1', 3, {}))

              expect(subject.length).to eq(2)

              expect(subject[0][:new].size).to eq(6)
              expect(subject[0][:old].size).to eq(3)

              expect(subject[1][:new].size).to eq(12)
              expect(subject[1][:old].size).to eq(3)
            end
          end
        end
      end
    end
  end
end
