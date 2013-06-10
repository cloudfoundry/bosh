require 'spec_helper'

describe Bosh::Agent::Platform::Centos::Disk do
  it 'should override the default Linux detect_block_device method' do
    Dir.should_receive(:glob).with("/sys/bus/scsi/devices/0:0:1:0/block/*", 0).and_return(["/sys/bus/scsi/devices/0:0:1:0/block/sda"])
    expect(subject.detect_block_device("1")).to eq "sda"
  end

  it 'should override the default Linux rescan_scsi_bus method' do
    pending 'refactoring needed as rescan_scsi_bus is a private method'
  end
end
