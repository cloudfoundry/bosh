require 'spec_helper'
require 'bosh/dev/aws/bat_deployment_manifest'

module Bosh::Dev::Aws
  describe BatDeploymentManifest do
    let(:bosh_cli_session) { instance_double('Bosh::Dev::Bat::BoshCliSession') }
    let(:archive) { instance_double('Bosh::Dev::Bat::StemcellArchive', version: 'fake-version') }
    let(:receipts) do
      instance_double('Bosh::Dev::Bat::Receipts',
                      vpc_outfile_path: 'fake_vpc_outfile_path',
                      route53_outfile_path: 'fake_route53_outfile_path'
      )
    end

    subject(:manifest) { described_class.new(bosh_cli_session, archive) }

    before do
      Bosh::Dev::Aws::Receipts.stub(:new).and_return(receipts)
      Bosh::Dev::Bat::BoshCliSession.stub(:new).and_return(bosh_cli_session)
    end

    describe '#write' do
      it 'uses the command line tool to generate the manifest' do
        bosh_cli_session.should_receive(:run_bosh).with("aws generate bat 'fake_vpc_outfile_path' 'fake_route53_outfile_path' 'fake-version'")
        manifest.write
      end
    end
  end
end
