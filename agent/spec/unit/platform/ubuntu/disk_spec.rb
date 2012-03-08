require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Config.platform_name = "ubuntu"
Bosh::Agent::Config.platform

describe Bosh::Agent::Platform::Ubuntu::Disk do

  before(:each) do
    Bosh::Agent::Config.settings = { 'disks' => { 'persistent' => { 2 => '333'} } }
  end

  it 'should mount persistent disk' do
    infrastructure = mock(:infrastructure)
    Bosh::Agent::Config.stub(:infrastructure).and_return(infrastructure)
    infrastructure.stub(:lookup_disk_by_cid).and_return("/dev/sdy")
    disk_wrapper = Bosh::Agent::Platform::Ubuntu::Disk.new
    File.stub(:blockdev?).and_return(true)
    disk_wrapper.stub(:mount_entry).and_return(nil)
    disk_wrapper.stub(:mount)
    disk_wrapper.mount_persistent_disk(2)
  end

end
