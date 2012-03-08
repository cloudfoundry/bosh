require File.dirname(__FILE__) + '/../../../spec_helper'

Bosh::Agent::Infrastructure.new("aws").infrastructure

describe Bosh::Agent::Infrastructure::Aws::Disk do

  before(:each) do
    Bosh::Agent::Config.settings = { 'disks' => { 'ephemeral' => "/dev/sdq",
                                                  'persistent' => { 2 => '/dev/sdf'} } }
  end

  it 'should get data disk device name' do
    disk_wrapper = Bosh::Agent::Infrastructure::Aws::Disk.new
    lambda {
      disk_wrapper.get_data_disk_device_name.should == '/dev/sdq'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdq or \/dev\/xvdq/)
  end

  it 'should look up disk by cid' do
    disk_wrapper = Bosh::Agent::Infrastructure::Aws::Disk.new
    disk_wrapper.stub(:dev_path_timeout).and_return(1)
    lambda {
      disk_wrapper.lookup_disk_by_cid(2).should == '/dev/sdf'
    }.should raise_error(Bosh::Agent::FatalError, /\/dev\/sdf or \/dev\/xvdf/)
  end

end
