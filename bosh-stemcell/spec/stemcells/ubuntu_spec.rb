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
  end

  describe 'Files' do
    describe file('/var/vcap/micro/apply_spec.yml') do
      it { should be_file }
      it { should contain 'deployment: micro' }
    end
  end
end
