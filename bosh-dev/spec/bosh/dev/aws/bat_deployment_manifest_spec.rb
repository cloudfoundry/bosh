require 'spec_helper'
require 'bosh/dev/aws/bat_deployment_manifest'

module Bosh::Dev::Aws
  describe BatDeploymentManifest do
    subject { described_class.new(env, bosh_cli_session, 'STEMCELL_VERSION') }
    let(:env) { {} }
    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

    let(:receipts) do
      instance_double(
        'Bosh::Dev::Aws::Receipts',
        vpc_outfile_path: 'fake_vpc_outfile_path',
        route53_outfile_path: 'fake_route53_outfile_path'
      )
    end

    before { Bosh::Dev::Aws::Receipts.stub(:new).and_return(receipts) }

    describe '#write' do
      it 'uses the command line tool to generate the manifest' do
        bosh_cli_session.should_receive(:run_bosh).with(
          "aws generate bat 'fake_vpc_outfile_path' 'fake_route53_outfile_path' 'STEMCELL_VERSION'")
        subject.write
      end
    end
  end
end
