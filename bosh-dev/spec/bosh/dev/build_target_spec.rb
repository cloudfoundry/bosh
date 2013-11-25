require 'spec_helper'
require 'bosh/dev/build_target'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  describe BuildTarget do
    describe '.from_names' do
      it 'returns target with proper build, infrastructure, and operating_system' do
        infrastructure = instance_double('Bosh::Stemcell::Infrastructure::Base')
        Bosh::Stemcell::Infrastructure
          .should_receive(:for)
          .with('fake-infrastructure-name')
          .and_return(infrastructure)

        operating_system = instance_double('Bosh::Stemcell::OperatingSystem::Base')
        Bosh::Stemcell::OperatingSystem
          .should_receive(:for)
          .with('fake-operating-system-name')
          .and_return(operating_system)

        build_target = described_class.from_names(
          'fake-build-number',
          'fake-infrastructure-name',
          'fake-operating-system-name',
        )

        expect(build_target.build_number).to eq('fake-build-number')
        expect(build_target.infrastructure).to eq(infrastructure)
        expect(build_target.operating_system).to eq(operating_system)
        expect(build_target.infrastructure_light?).to be(false)
      end
    end
  end
end
