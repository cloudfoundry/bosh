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

      it 'must ignore ICMPv6 redirects by default (stig: V-38548)' do
        should contain /^net.ipv6.conf.default.accept_redirects=0$/
      end

      it 'must not accept ICMPv4 secure redirect packets by default (stig: V-38532)' do
        should contain /^net.ipv4.conf.default.secure_redirects=0$/
      end

      it 'must not send ICMPv4 redirects by default (stig: V-38600)' do
        should contain /^net.ipv4.conf.default.send_redirects=0$/
      end

      it 'must not send ICMPv4 redirects from any interface. (stig: V-38601)' do
        should contain /^net.ipv4.conf.all.send_redirects=0$/
      end

      it 'must use reverse path filtering for IPv4 network traffic on all interfaces. (stig: V-38542) (CIS-7.2.7)' do
        should contain /^net.ipv4.conf.all.rp_filter=1$/
      end

      it 'must use reverse path filtering for IPv4 network traffic by default. (stig: V-38544) (CIS-7.2.7)' do
        should contain /^net.ipv4.conf.default.rp_filter=1$/
      end

      it 'should disable ipv6 router advertisements on all interfaces (CIS-7.3.1)' do
        should contain /^net.ipv6.conf.all.accept_ra=0$/
      end

      it 'should disable ipv6 router advertisements by default (CIS-7.3.1)' do
        should contain /^net.ipv6.conf.default.accept_ra=0$/
      end

      it 'should flush ipv6 routes (CIS-7.3.1)' do
        should contain /^net.ipv6.route.flush=1$/
      end

      it 'should disable response to broadcast requests (CIS-7.2.5)' do
        should contain /^net.ipv4.icmp_echo_ignore_broadcasts=1$/
      end

      it 'enables bad error message protection (CIS-7.2.6)' do
        should contain /^net.ipv4.icmp_ignore_bogus_error_responses=1$/
      end

      it 'should disable core dumps (CIS-4.1)' do
        should contain /^fs.suid_dumpable=0$/
      end
    end

    describe file('/etc/sysctl.d/60-bosh-sysctl-neigh-fix.conf') do
      it { should be_file }
    end

    context 'installed by system_ixgbevf' do
      describe package('dkms'), exclude_on_ppc64le: true do
        it { should be_installed }
      end

      describe 'the ixgbevf kernel module', exclude_on_ppc64le: true  do
        it 'is installed with the right version' do
          expect(file("/var/lib/dkms/ixgbevf/3.1.1/#{kernel_version}/x86_64/module/ixgbevf.ko")).to be_a_file
        end
      end
    end
  end
end
