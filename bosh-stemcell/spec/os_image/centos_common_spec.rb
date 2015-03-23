require 'spec_helper'

describe 'All CentOS versions', os_image: true do

  describe package('apt') do
    it { should_not be_installed }
  end

  describe package('rpm') do
    it { should be_installed }
  end

  context 'installed by base_centos' do
    %w(
      centos-release
      epel-release
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    %w(
      firewalld
    ).each do |pkg|
      describe package(pkg) do
        it { should_not be_installed }
      end
    end

    describe file('/etc/sysconfig/network') do
      it { should be_file }
    end

    describe file('/etc/localtime') do
      it { should be_file }
      it { should contain 'UTC' }
    end

    describe file('/etc/sysconfig/i18n') do
      it { should be_file }
      it { should contain 'en_US.UTF-8' }
    end
  end


  context 'installed by base_ssh' do
    subject(:sshd_config) { file('/etc/ssh/sshd_config') }

    it 'disallows CBC ciphers' do
      ciphers = %w(
        aes256-ctr
        aes192-ctr
        aes128-ctr
      ).join(',')
      expect(sshd_config).to contain(/^Ciphers #{ciphers}$/)
    end

    it 'disallows insecure HMACs' do
      macs = %w(
        hmac-sha2-512
        hmac-sha2-256
        hmac-ripemd160
      ).join(',')
      expect(sshd_config).to contain(/^MACs #{macs}$/)
    end
  end

  context 'installed by system_kernel' do
    %w(
      kernel
      kernel-headers
    ).each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end
  end

  context 'readahead-collector should be disabled' do
    describe file('/etc/sysconfig/readahead') do
      it { should be_file }
      it { should contain 'READAHEAD_COLLECT="no"' }
      it { should contain 'READAHEAD_COLLECT_ON_RPM="no"' }
    end
  end
end
