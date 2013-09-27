require 'spec_helper'
require 'bosh/dev/bat/director_uuid'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Bat
  describe DirectorUuid do
    describe '#value' do
      subject { described_class.new(cli_session) }
      let(:cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

      context 'when we are able to extract uuid' do
        before { cli_session.stub(:run_bosh).and_return(<<-OUTPUT) }
Director
  Name       bosh_micro01
  URL        https://192.168.56.2:25555
  Version    1.5.0.pre.896 (release:f694e3d2 bosh:f694e3d2)
  User       admin
  UUID       39be73f2-103a-4968-9645-9cd6406aedce
  CPI        workstation
  dns        enabled (domain_name: microbosh)
        OUTPUT

        it 'fetches output via bosh status' do
          cli_session.should_receive(:run_bosh).with('status')
          subject.value
        end

        it 'returns fetched uuid via `bosh status`' do
          expect(subject.value).to eq('39be73f2-103a-4968-9645-9cd6406aedce')
        end
      end

      context 'when we are not able to extract uuid' do
        before { cli_session.stub(:run_bosh).and_return('output') }

        it 'raises an error' do
          expect {
            subject.value
          }.to raise_error(described_class::UnknownUuidError, /output/)
        end
      end
    end
  end
end
