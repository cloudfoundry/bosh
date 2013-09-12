require 'spec_helper'

module Bosh::Agent
  describe Platform do
    describe '.platform' do
      subject(:factory) do
        Bosh::Agent::Platform
      end

      before do
        config_double = class_double('Bosh::Agent::Config').as_stubbed_const
        config_double.stub(:infrastructure)
        config_double.stub(:platform_name)
        config_double.stub(:logger)
        config_double.stub(base_dir: '/fake/base_dir')
        config_double.stub(system_root: '/fake/system_root')
      end

      context 'when the platform_name is "ubuntu"' do
        subject(:platform) do
          factory.platform('ubuntu')
        end

        it 'uses a generic logrotate strategy' do
          platform.instance_variable_get(:@logrotate).should be_an_instance_of Platform::Linux::Logrotate
          platform.instance_variable_get(:@logrotate).instance_variable_get(:@template_src).should include('lib/bosh_agent/platform/ubuntu/templates')
        end

        it 'uses a generic password strategy' do
          platform.instance_variable_get(:@password).should be_an_instance_of Platform::Linux::Password
        end

        it 'uses a generic disk strategy' do
          platform.instance_variable_get(:@disk).should be_an_instance_of Platform::Linux::Disk
        end

        it 'uses an ubuntu-specific network strategy' do
          platform.instance_variable_get(:@network).should be_an_instance_of Platform::Ubuntu::Network
          platform.instance_variable_get(:@network).instance_variable_get(:@template_dir).should include('lib/bosh_agent/platform/ubuntu/templates')
        end
      end

      context 'when the platform_name is "centos"' do
        subject(:platform) do
          factory.platform('centos')
        end

        it 'uses a generic logrotate strategy with a centos-specific template' do
          platform.instance_variable_get(:@logrotate).should be_an_instance_of Platform::Linux::Logrotate
          platform.instance_variable_get(:@logrotate).instance_variable_get(:@template_src).should include('lib/bosh_agent/platform/centos/templates')
        end

        it 'uses a generic password strategy' do
          platform.instance_variable_get(:@password).should be_an_instance_of Platform::Linux::Password
        end

        it 'uses a centos-specific disk strategy' do
          platform.instance_variable_get(:@disk).should be_an_instance_of Platform::Centos::Disk
        end

        it 'uses a centos-specific network strategy' do
          platform.instance_variable_get(:@network).should be_an_instance_of Platform::Centos::Network
          platform.instance_variable_get(:@network).instance_variable_get(:@template_dir).should include('lib/bosh_agent/platform/centos/templates')
        end
      end

      context 'when the platform_name is anything else' do
        it 'blows up with a sensible error for "osx"' do
          expect {
            factory.platform('osx')
          }.to raise_error UnknownPlatform, "platform 'osx' not found"
        end
      end
    end
  end
end
