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
        it 'returns an Ubuntu compatible platform implementation' do
          expect(factory.platform('ubuntu')).to be_an_instance_of(Platform::Ubuntu::Adapter)
        end
      end

      context 'when the platform_name is "centos"' do
        it 'returns an CentOS compatible platform implementation' do
          expect(factory.platform('centos')).to be_an_instance_of(Platform::Centos::Adapter)
        end
      end

      context 'when the platform_name is "rhel"' do
        it 'returns an CentOS compatible platform implementation' do
          expect(factory.platform('rhel')).to be_an_instance_of(Platform::Rhel::Adapter)
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
