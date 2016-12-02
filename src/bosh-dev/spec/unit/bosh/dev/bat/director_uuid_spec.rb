require 'spec_helper'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Bat
  describe DirectorUuid do
    describe '#value' do
      subject { described_class.new(cli_session) }
      let(:cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

      context 'when we are able to extract uuid' do
        before { allow(cli_session).to receive(:run_bosh).with('status --uuid').and_return(<<-OUTPUT) }
39be73f2-103a-4968-9645-9cd6406aedce
        OUTPUT

        it 'returns fetched uuid via `bosh status --uuid`' do
          expect(subject.value).to eq('39be73f2-103a-4968-9645-9cd6406aedce')
        end
      end

      context 'when we are not able to obtain a uuid' do
        before { allow(cli_session).to receive(:run_bosh).with('status --uuid') { Bosh::Core::Shell.new.run('false') } }

        it 'raises an error' do
          expect {
            subject.value
          }.to raise_error
        end
      end
    end
  end
end
