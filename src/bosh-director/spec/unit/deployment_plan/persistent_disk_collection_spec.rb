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

    describe PersistentDiskCollection::PersistentDisk do

      describe '#size_diff_only?' do
        let(:old_disk) { old_disk = PersistentDiskCollection::PersistentDisk.new('', {}, 10) }

        context 'when the size is the only difference' do
          it 'is true' do
            new_disk = PersistentDiskCollection::PersistentDisk.new('', {}, 20)

            expect(old_disk.size_diff_only?(new_disk)).to eq(true)
          end
        end

        context 'when the size did not change' do
          it 'is false' do
            new_disk = PersistentDiskCollection::PersistentDisk.new('', {}, 10)

            expect(old_disk.size_diff_only?(new_disk)).to eq(false)
          end
        end

        context 'when the other properties changed' do
          context 'when the size is the same' do
            it 'is false' do
              new_disk = PersistentDiskCollection::PersistentDisk.new('', {'some_property' => 'value'}, 10)

              expect(old_disk.size_diff_only?(new_disk)).to eq(false)
            end
          end

          context 'when also the size has changed' do
            it 'is false' do
              new_disk = PersistentDiskCollection::PersistentDisk.new('other_name', {}, 20)

              expect(old_disk.size_diff_only?(new_disk)).to eq(false)
            end
          end
        end

        context 'when other is not a PersistentDisk' do
          it 'is false' do
            new_disk = nil

            expect(old_disk.size_diff_only?(new_disk)).to eq(false)
          end
        end
      end
    end
  end
end
