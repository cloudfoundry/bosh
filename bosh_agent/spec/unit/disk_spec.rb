require 'spec_helper'
require 'bosh_agent/disk'

describe Bosh::Agent::Disk do
  subject(:disk) { Bosh::Agent::Disk.new('/dev/sdb') }
  its(:partition_path) { should eq('/dev/sdb1')}

  describe '#mount' do
    it 'mounts the partition onto the given path' do
      disk.should_receive(:`).with('mount  /dev/sdb1 /fake/mount')

      disk.mount('/fake/mount', '').should eq(true)
    end
  end
end
