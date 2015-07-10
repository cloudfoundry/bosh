shared_examples_for 'a Linux kernel 3.x based OS image' do

  def kernel_version
    command('ls /lib/modules').stdout.chomp
  end

  context 'installed by bosh_sysctl' do
    describe file('/etc/sysctl.d/60-bosh-sysctl.conf') do
      it { should be_file }
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
