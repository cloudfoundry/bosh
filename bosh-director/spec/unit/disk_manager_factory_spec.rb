require 'spec_helper'

module Bosh::Director
  describe Bosh::Director::DiskManagerFactory do
    subject(:disk_manager_factory) { DiskManagerFactory.new(cloud, logger) }

    let(:cloud) { Config.cloud }

    describe '#create' do
      context 'when using multiple persistent disks' do
        it 'returns a MultipleDisksManager' do
          expect(disk_manager_factory.new_disk_manager(multiple_disks: true)).to be_a(MultipleDisksManager)
        end
      end
    end

    context 'when using a single persistent disk' do
      it 'returns a SingleDiskManager' do
        expect(disk_manager_factory.new_disk_manager(multiple_disks: false)).to be_a(SingleDiskManager)
      end
    end

    context 'by default' do
      it 'returns a SingleDiskManager' do
        expect(disk_manager_factory.new_disk_manager).to be_a(SingleDiskManager)
      end
    end
  end
end
