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
      let(:definition) {
        instance_double(
          'Bosh::Stemcell::Definition',
          infrastructure: infrastructure,
        )
      }

      before do

        allow(Bosh::Stemcell::Definition).to receive(:for).and_return(definition)
      end

      context 'when infrastructure is not light' do
        before { allow(infrastructure).to receive(:light?).and_return(false) }

        its(:build_number) { should eq('fake-build-number') }
        its(:definition) { should eq(definition) }
        its(:infrastructure) { should eq(infrastructure) }
        its(:infrastructure_light?) { should be(false) }

        it 'builds definition using infrastructure and operating system names and hardcoded ruby' do
          subject.definition

          expect(Bosh::Stemcell::Definition).to have_received(:for)
            .with('fake-infrastructure-name', 'fake-operating-system-name', 'ruby')
        end
      end

      context 'when infrastructure is light' do
        before { allow(infrastructure).to receive(:light?).and_return(true) }

        its(:build_number) { should eq('fake-build-number') }
        its(:infrastructure_light?) { should be(true) }
      end
    end
  end
end
