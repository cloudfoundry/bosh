require 'spec_helper'
require 'bosh/dev/build_target'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Dev
  describe BuildTarget do
    let(:light) { false }

    subject(:build_target) do
      described_class.from_names(
        'fake-build-number',
        'fake-infrastructure-name',
        'fake-hypervisor-name',
        'fake-operating-system-name',
        'fake-operating-system-version',
        'fake-agent-name',
        light
      )
    end

    describe '.from_names' do
      let(:infrastructure) { instance_double('Bosh::Stemcell::Infrastructure::Base') }
      let(:definition) do
        instance_double(
          'Bosh::Stemcell::Definition',
          infrastructure: infrastructure,
          light?: light
        )
      end

      before do
        allow(Bosh::Stemcell::Definition).to receive(:for).and_return(definition)
      end

      its(:build_number) { should eq('fake-build-number') }
      its(:definition) { should eq(definition) }
      its(:infrastructure) { should eq(infrastructure) }

      it 'builds definition using infrastructure and operating system names and hardcoded ruby' do
        subject.definition

        expect(Bosh::Stemcell::Definition).to have_received(:for).with(
          'fake-infrastructure-name',
          'fake-hypervisor-name',
          'fake-operating-system-name',
          'fake-operating-system-version',
          'fake-agent-name',
          light
        )
      end
    end
  end
end
