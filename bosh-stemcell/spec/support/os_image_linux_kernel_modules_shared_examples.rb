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

  context 'prevent cramfs module from being loaded (CIS-2.18)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install cramfs /bin/true' }
    end
  end

  context 'prevent freevxfs module from being loaded (CIS-2.19)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install freevxfs /bin/true' }
    end
  end
  context 'prevent jffs2 module from being loaded (CIS-2.20)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install jffs2 /bin/true' }
    end
  end
  context 'prevent hfs module from being loaded (CIS-2.21)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install hfs /bin/true' }
    end
  end
  context 'prevent hfsplus module from being loaded (CIS-2.22)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install hfsplus /bin/true' }
    end
  end
  context 'prevent squashfs module from being loaded (CIS-2.23)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install squashfs /bin/true' }
    end
  end
  context 'disable RDS (CIS-7.5.3)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install rds /bin/true' }
    end
  end
end
