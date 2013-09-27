require 'spec_helper'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev::Aws
  describe MicroBoshDeploymentManifest do
    subject { described_class.new(env, bosh_cli_session) }
    let(:env) { {} }
    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

    let(:receipts) do
      instance_double(
        'Bosh::Dev::Aws::Receipts',
        vpc_outfile_path: 'fake_vpc_outfile_path',
        route53_outfile_path: 'fake_route53_outfile_path',
      )
    end

    before do
      Receipts.stub(:new).and_return(receipts)
      Bosh::Dev::BoshCliSession.stub(:new).and_return(bosh_cli_session)
    end

    describe '#write' do
      it 'uses the command line tool to generate the manifest' do
        bosh_cli_session.should_receive(:run_bosh).with(
          "aws generate micro_bosh 'fake_vpc_outfile_path' 'fake_route53_outfile_path'")
        subject.write
      end
    end
  end
end
