require 'spec_helper'

module Bosh::Agent
  describe Configuration do
    describe '.platform' do
      subject(:configuration) do
        Configuration.new
      end

      let(:platform_class) { class_double('Bosh::Agent::Platform') }

      before do
        @ubuntu = instance_double('Bosh::Agent::Platform::Linux::Adapter')
        platform_class.as_stubbed_const
        configuration.setup('platform_name' => 'ubuntu', 'infrastructure_name' => 'dummy')
      end

      it 'delegates to Bosh::Agent::Platform to determine the implementation' do
        platform_class.should_receive(:platform).with('ubuntu').and_return(@ubuntu)
        expect(configuration.platform).to be(@ubuntu)
      end
    end
  end
end
