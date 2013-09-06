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

    context 'installed by base_apt'

    context 'installed by bosh_micro'

    context 'installed by system_grub'

    context 'installed by system_kernel'
  end

  describe 'Files' do
    describe file('/var/vcap/micro/apply_spec.yml')
  end
end
