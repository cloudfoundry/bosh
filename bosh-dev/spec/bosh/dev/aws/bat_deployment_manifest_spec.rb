require 'spec_helper'
require 'bosh/dev/aws/bat_deployment_manifest'
require 'bosh/stemcell/archive'

module Bosh::Dev::Aws
  describe BatDeploymentManifest do
    subject { described_class.new(env, bosh_cli_session, stemcell_archive) }
    let(:env) { {} }
    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession') }
    let(:stemcell_archive) { instance_double('Bosh::Stemcell::Archive', version: 13, name: 'stemcell-name') }

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
          "aws generate bat 'fake_vpc_outfile_path' 'fake_route53_outfile_path' '13' 'stemcell-name'")
        subject.write
      end
    end
  end
end
