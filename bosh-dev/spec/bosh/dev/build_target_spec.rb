require 'spec_helper'
require 'bosh/dev/build_target'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  describe BuildTarget do
    subject(:build_target) do
      described_class.from_names(
        'fake-build-number',
        'fake-infrastructure-name',
        'fake-operating-system-name',
      )
    end

    describe '.from_names' do
      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base') }
      let(:operating_system) { instance_double('Bosh::Stemcell::OperatingSystem::Base') }

      before do
        allow(Bosh::Stemcell::Infrastructure).to receive(:for).with('fake-infrastructure-name').and_return(infrastructure)

        allow(Bosh::Stemcell::OperatingSystem).to receive(:for).with('fake-operating-system-name').and_return(operating_system)
      end

      context 'when infrastructure is not light' do
        before { allow(infrastructure).to receive(:light?).and_return(false) }

        its(:build_number) { should eq('fake-build-number') }
        its(:infrastructure) { should eq(infrastructure) }
        its(:operating_system) { should eq(operating_system) }
        its(:infrastructure_light?) { should be(false) }
      end

      context 'when infrastructure is light' do
        before { allow(infrastructure).to receive(:light?).and_return(true) }

        its(:build_number) { should eq('fake-build-number') }
        its(:infrastructure) { should eq(infrastructure) }
        its(:operating_system) { should eq(operating_system) }
        its(:infrastructure_light?) { should be(true) }
      end
    end
  end
end
