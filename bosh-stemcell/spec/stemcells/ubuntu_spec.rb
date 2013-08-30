require 'spec_helper'

describe 'Ubuntu Stemcell' do
  before(:all) do
    pending 'ENV["SERVERSPEC_CHROOT"] must be set to test Stemcells' unless ENV['SERVERSPEC_CHROOT']
  end

  describe 'Packages' do
    describe package('apt') do
      it { should be_installed }
    end

    describe package('rpm') do
      it { should_not be_installed }
    end

    context 'installed by base_apt' do
      {
        'upstart'              => '0.6.5-8',
        'build-essential'      => '11.4build1',
        'libssl-dev'           => '0.9.8k-7ubuntu8.15',
        'lsof'                 => '4.81.dfsg.1-1build1',
        'strace'               => '4.5.19-2',
        'bind9-host'           => '1:9.7.0.dfsg.P1-1ubuntu0.10',
        'dnsutils'             => '1:9.7.0.dfsg.P1-1ubuntu0.10',
        'tcpdump'              => '4.0.0-6ubuntu3',
        'iputils-arping'       => '3:20071127-2ubuntu1',
        'curl'                 => '7.19.7-1ubuntu1.3',
        'wget'                 => '1.12-1.1ubuntu2.1',
        'libcurl3'             => '7.19.7-1ubuntu1.3',
        'libcurl4-openssl-dev' => '7.19.7-1ubuntu1.3', # installed because of 'libcurl3-dev'
        'bison'                => '1:2.4.1.dfsg-3',
        'libreadline6-dev'     => '6.1-1',
        'libxml2'              => '2.7.6.dfsg-1ubuntu1.10',
        'libxml2-dev'          => '2.7.6.dfsg-1ubuntu1.10',
        'libxslt1.1'           => '1.1.26-1ubuntu1.2',
        'libxslt1-dev'         => '1.1.26-1ubuntu1.2',
        'zip'                  => '3.0-2',
        'unzip'                => '6.0-1build1',
        'nfs-common'           => '1:1.2.0-4ubuntu4.2',
        'flex'                 => '2.5.35-9',
        'psmisc'               => '22.10-1',
        'apparmor-utils'       => '2.5.1-0ubuntu0.10.04.4',
        'iptables'             => '1.4.4-2ubuntu2',
        'sysstat'              => '9.0.6-2',
        'rsync'                => '3.0.7-1ubuntu1.1',
        'openssh-server'       => '1:5.3p1-3ubuntu7',
        'traceroute'           => '2.0.13-2',
        'libncurses5-dev'      => '5.7+20090803-2ubuntu3',
        'quota'                => '3.17-6',
        'libaio1'              => '0.3.107-3ubuntu2',
        'gdb'                  => '7.1-1ubuntu2',
        'tripwire'             => '2.3.1.2.0-13',
        'libcap2-bin'          => '1:2.17-2ubuntu1.1',
        'libyaml-dev'          => '0.1.3-1',
        'cmake'                => '2.8.0-5ubuntu1',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'installed by bosh_debs' do
      {
        'scsitools'        => '0.10-2.1ubuntu2',
        'mg'               => '20090107-3',
        'htop'             => '0.8.3-1ubuntu1',
        'module-assistant' => '0.11.2ubuntu1',
        'debhelper'        => '7.4.15ubuntu1',
        'runit'            => '2.0.0-1ubuntu4',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'installed by bosh_micro' do
      {
        'libpq-dev'   => '8.4.17-0ubuntu10.04',
        'genisoimage' => '9:1.1.10-1ubuntu1',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'installed by system_grub' do
      {
        'grub' => '0.97-29ubuntu60.10.04.2',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'installed by system_kernel' do
      {
        'linux-image-virtual-lts-backport-oneiric'   => '3.0.0.32.20',
        'linux-headers-virtual-lts-backport-oneiric' => '3.0.0.32.20',
      }.each do |pkg, version|
        describe package(pkg) do
          it { should be_installed.with_version(version) }
        end
      end
    end
  end

  describe 'Files' do
    describe file('/var/vcap/micro/apply_spec.yml') do
      it { should be_file }
      it { should contain 'deployment: micro' }
    end
  end
end
