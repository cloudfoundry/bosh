shared_examples_for 'a Linux kernel module configured OS image' do
  context 'prevent bluetooth module from being loaded (stig: V-38682)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should be_file }
      it { should contain 'install bluetooth /bin/true' }
    end
  end

  context 'prevent tipc module from being loaded (stig: V-38517)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install tipc /bin/true' }
    end
  end

  context 'prevent sctp module from being loaded (stig: V-38515)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install sctp /bin/true' }
    end
  end

  context 'prevent dccp module from being loaded (stig: V-38514)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install dccp /bin/true' }
    end
  end

  context 'prevent bluetooth service from being enabled (stig: V-38691)' do
    describe service('bluetooth') do
      it { should_not be_enabled }
    end
  end

  context 'prevent USB module from being loaded (stig: V-38490)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install usb-storage /bin/true' }
    end
  end

  context 'prevent ipv6 module from being loaded (stig: V-38546) (stig: V-38444) (stig: V-38553) (stig: V-38551)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'options ipv6 disable=1' }
    end
  end
end
