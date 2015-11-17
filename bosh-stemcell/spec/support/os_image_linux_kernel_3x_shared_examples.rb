shared_examples_for 'a Linux kernel 3.x based OS image' do

  def kernel_version
    command('ls /lib/modules').stdout.chomp
  end

  context 'installed by bosh_sysctl' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      it { should be_file }

      it 'must not accept ICMPv4 secure redirect packets on any interface (stig: V-38526)' do
        should contain /^net.ipv4.conf.all.secure_redirects=0$/
      end

      it 'must not accept ICMPv4 redirect packets on any interface (stig: V-38524)' do
        should contain /^net.ipv4.conf.all.accept_redirects=0$/
      end

      it 'must not accept IPv4 source-routed packets by default (stig: V-38529)' do
        should contain /^net.ipv4.conf.default.accept_source_route=0$/
      end

      it 'must not accept IPv4 source-routed packets on any interface (stig: V-38523)' do
        should contain /^net.ipv4.conf.all.accept_source_route=0$/
      end
    end

    describe file('/etc/sysctl.d/60-bosh-sysctl-neigh-fix.conf') do
      it { should be_file }
    end

    context 'installed by system_ixgbevf' do
      describe package('dkms') do
        it { should be_installed }
      end

      describe 'the ixgbevf kernel module' do
        it 'is installed with the right version' do
          expect(file("/var/lib/dkms/ixgbevf/2.16.1/#{kernel_version}/x86_64/module/ixgbevf.ko")).to be_a_file
        end
      end
    end
  end
end
