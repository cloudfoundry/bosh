require 'spec_helper'

describe 'CentOs Stemcell' do
  before(:all) do
    pending 'ENV["SERVERSPEC_CHROOT"] must be set to test Stemcells' unless ENV['SERVERSPEC_CHROOT']
  end

  describe 'Packages' do
    describe package('apt') do
      it { should_not be_installed }
    end

    describe package('rpm') do
      it { should be_installed }
    end

    context 'installed by base_yum' do
      {
        # 'upstart'        => '0.6.5-8',

        'openssl-devel'  => '1.0.0-27.el6_4.2',
        'lsof'           => '4.82-4.el6.x86_64',
        'libxml2'        => '2.7.6-12.el6_4.1.x86_64',
        'quota'          => '3.17-18.el6.x86_64',
        'rsync'          => '3.0.6-9.el6.x86_64',
        'strace'         => '4.5.19-1.17.el6.x86_64',
        'iptables'       => '1.4.7-9.el6.x86_64',
        'sysstat'        => '9.0.4-20.el6.x86_64',
        'tcpdump'        => '4.0.0-3.20090921gitdf3cb4.2.el6.x86_64',
        'zip'            => '3.0-1.el6.x86_64',
        'traceroute'     => '2.0.14-2.el6.x86_64',
        'gdb'            => '7.2-60.el6_4.1.x86_64',
        'curl'           => '7.19.7-37.el6_4.x86_64',
        'flex'           => '2.5.35-8.el6.x86_64',
        'openssh-server' => '5.3p1-84.1.el6',
        'wget'           => '1.12-1.8.el6.x86_64',
        'psmisc'         => '22.6-15.el6_0.1.x86_64',
        'unzip'          => '6.0-1.el6.x86_64',
        'bison'          => '2.4.1-5.el6.x86_64',
        'cmake'          => '2.6.4-5.el6.x86_64',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'installed by bosh_micro'

    context 'installed by system_grub'

    context 'installed by system_kernel'
  end

  describe 'Files' do
    describe file('/var/vcap/micro/apply_spec.yml')
  end
end
