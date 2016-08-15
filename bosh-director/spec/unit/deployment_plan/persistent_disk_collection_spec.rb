require 'spec_helper'

module Bosh::Director
  module DeploymentPlan
    describe PersistentDiskCollection do
      let(:persistent_disk_collection) { PersistentDiskCollection.new(logger, options) }
      let(:options) { {} }
      let(:disk_size) { 30 }
      let(:cloud_properties) { {} }
      let(:disk_type) { DiskType.new('disk_name', disk_size, cloud_properties) }

      describe '#add_by_disk_size' do
        let(:options) { {multiple_disks: false} }

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
          let(:options) { {multiple_disks: false} }

          it 'does not add disk to collection' do
            persistent_disk_collection.add_by_disk_size(0)

            expect(persistent_disk_collection.generate_spec).to eq( { 'persistent_disk' => 0 } )
          end
        end
      end

      describe '#add_by_disk_type' do
        let(:options) { {multiple_disks: false} }

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
        let(:options) { {multiple_disks: true} }

        it 'adds multiple disks given disk name and type' do
          persistent_disk_collection.add_by_disk_name_and_type('first_disk', disk_type)
          persistent_disk_collection.add_by_disk_name_and_type('another_disk', disk_type)

          disk_spec = persistent_disk_collection.generate_spec

          expect(disk_spec['persistent_disks']).to eq([
            {'disk_size' => 30, 'disk_name' => 'first_disk'},
            {'disk_size' => 30, 'disk_name' => 'another_disk'},
          ])
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
          let(:options) { {multiple_disks: true} }

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
        context 'when using a single disk' do
          let(:persistent_disk_models) { [] }

          context 'when there are no disks in the persistent disk collection' do
            context 'when deployment has no disks' do
              it 'returns false' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(false)
              end
            end
            context 'when deployment has disks' do
              let(:persistent_disk_models) { [Models::PersistentDisk.make(size: 3)] }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
                end

              it 'logs' do
                expect(logger).to receive(:debug).with('Persistent disk size changed FROM: 3 TO: 0')

                persistent_disk_collection.is_different_from(persistent_disk_models)
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
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
              end
            end

            context 'when deployment has one disk' do
              let(:persistent_disk_models) do
                [Models::PersistentDisk.make(size: 30, cloud_properties: {})]
              end

              context 'when disks are the same' do
                it 'returns false' do
                  expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(false)
                end
              end

              context 'when disk sizes are different' do
                let(:disk_size) { 4 }

                it 'returns true' do
                  expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
                end
              end

              context 'when disk cloud properties are different' do
                let(:cloud_properties) { {'some' => 'cloud'} }

                it 'returns true' do
                  expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
                end

                it 'logs' do
                  expect(logger).to receive(:debug).with('Persistent disk cloud properties changed FROM: {} TO: {"some"=>"cloud"}')

                  persistent_disk_collection.is_different_from(persistent_disk_models)
                end
              end
            end
          end
        end

        context 'when using multiple disks' do
          let(:options) { { multiple_disks: true } }

          before do
            persistent_disk_collection.add_by_disk_name_and_type('disk1', disk_type)
            persistent_disk_collection.add_by_disk_name_and_type('disk2', disk_type)
          end

          context 'when deployment has one legacy disk' do
            let(:persistent_disk_models) { [
              Models::PersistentDisk.make(size: 3)
            ] }
            it 'returns true' do
              expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
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
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(false)
              end
            end

            context 'when number of disks is different' do
              before do
                persistent_disk_collection.add_by_disk_name_and_type('disk3', disk_type)
              end

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
              end
            end

            context 'when there is a disk with size disagreement' do
              let(:disk_size) { 4 }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
              end
            end

            context 'when there is a disk with cloud config disagreement' do
              let(:cloud_properties) { { 'a' => 'b' } }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
              end
            end

            context 'when there is a disk with name disagreement' do
              let(:persistent_disk_models) { [
                Models::PersistentDisk.make(name: 'disk13', size: 3),
                Models::PersistentDisk.make(name: 'disk2', size: 3),
              ] }

              it 'returns true' do
                expect(persistent_disk_collection.is_different_from(persistent_disk_models)).to be(true)
              end
            end
          end
        end
      end
    end
  end
end
