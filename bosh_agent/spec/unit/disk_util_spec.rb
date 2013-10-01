require 'spec_helper'

describe Bosh::Agent::DiskUtil do
  describe '#get_usage' do
    it 'should return the disk usage' do
      base = Bosh::Agent::Config.base_dir

      fs_list = [
        double('system', :dir_name => '/'),
        double('ephermal', :dir_name => File.join(base, 'data')),
        double('persistent', :dir_name => File.join(base, 'store'))
      ]

      sigar = double('sigar', :file_system_list => fs_list, :logger= => nil)

      u1 = double('usage', :use_percent => 0.69)
      sigar.should_receive(:file_system_usage).with('/').and_return(u1)

      u2 = double('usage', :use_percent => 0.73)
      sigar.should_receive(:file_system_usage).with(File.join(base, 'data')).and_return(u2)

      u3 = double('usage', :use_percent => 0.11)
      sigar.should_receive(:file_system_usage).with(File.join(base, 'store')).and_return(u3)

      Sigar.stub(:new => sigar)

      described_class.get_usage.should == {
        :system => {:percent => '69'},
        :ephemeral => {:percent => '73'},
        :persistent => {:percent => '11'}
      }
    end

    it 'should not return ephemeral and persistent disks usages if do not exist' do
      base = Bosh::Agent::Config.base_dir

      fs_list = [
        double('system', :dir_name => '/'),
      ]

      sigar = double('sigar', :file_system_list => fs_list, :logger= => nil)

      u1 = double('usage', :use_percent => 0.69)
      sigar.should_receive(:file_system_usage).with('/').and_return(u1)

      sigar.should_not_receive(:file_system_usage).with(File.join(base, 'data'))

      sigar.should_not_receive(:file_system_usage).with(File.join(base, 'store'))

      Sigar.stub(:new => sigar)

      described_class.get_usage.should == {
        :system => {:percent => '69'}
      }
    end
  end
end
