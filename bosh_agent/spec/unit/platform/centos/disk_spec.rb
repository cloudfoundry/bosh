require 'spec_helper'

describe Bosh::Agent::Platform::Centos::Disk do
  describe 'detect_block_device' do
    let(:host_glob) { '/sys/bus/scsi/devices/*:0:0:0/block/*' }

    context 'with scsi host 0' do
      let(:device_path) { '/sys/bus/scsi/devices/0:0:2:0/block/sdc' }
      let(:device_glob) { '/sys/bus/scsi/devices/0:0:2:0/block/*' }
      let(:device_list) { %w[/sys/bus/scsi/devices/0:0:0:0/block/sda /sys/bus/scsi/devices/1:0:0:0/block/sr0] }

      it 'should override the default Linux detect_block_device method' do
        Dir.should_receive(:glob).with(host_glob).and_return(device_list)

        Dir.should_receive(:glob).with(device_glob).and_return([device_path])
        expect(subject.detect_block_device('2')).to eq 'sdc'
      end
    end

    context 'with scsi host 2' do
      let(:device_path) { '/sys/bus/scsi/devices/2:0:2:0/block/sdc' }
      let(:device_glob) { '/sys/bus/scsi/devices/2:0:2:0/block/*' }
      let(:device_list) { %w[/sys/bus/scsi/devices/0:0:0:0/block/sr0 /sys/bus/scsi/devices/2:0:0:0/block/sda] }

      it 'should override the default Linux detect_block_device method' do
        Dir.should_receive(:glob).with(host_glob).and_return(device_list)

        Dir.should_receive(:glob).with(device_glob).and_return([device_path])
        expect(subject.detect_block_device('2')).to eq 'sdc'
      end
    end
  end
end
