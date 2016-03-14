shared_examples_for 'a Linux kernel module configured OS image' do
  context 'prevent bluetooth module to be loaded (stig: V-38682)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should be_file }
      it { should contain 'install bluetooth /bin/true' }
    end
  end

  context 'prevent tipc module to be loaded (stig: V-38517)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install tipc /bin/true' }
    end
  end

  context 'prevent sctp module to be loaded (stig: V-38515)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install sctp /bin/true' }
    end
  end

  context 'prevent dccp module to be loaded (stig: V-38514)' do
    describe file('/etc/modprobe.d/blacklist.conf') do
      it { should contain 'install dccp /bin/true' }
    end
  end

  context 'prevent bluetooth service to be enabled (stig: V-38691)' do
    describe service('bluetooth') do
      it { should_not be_enabled }
    end
  end
end
