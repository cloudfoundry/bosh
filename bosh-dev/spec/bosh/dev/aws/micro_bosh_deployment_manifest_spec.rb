require 'spec_helper'
require 'bosh/dev/aws/micro_bosh_deployment_manifest'

module Bosh::Dev::Aws
  describe MicroBoshDeploymentManifest do
    let(:bosh_cli_session) { instance_double('Bosh::Dev::Bat::BoshCliSession') }
    let(:receipts) do
      instance_double('Bosh::Dev::Bat::Receipts',
                      vpc_outfile_path: 'fake_vpc_outfile_path',
                      route53_outfile_path: 'fake_route53_outfile_path'
      )
    end

    subject { described_class.new(bosh_cli_session) }

    before do
      Receipts.stub(:new).and_return(receipts)
      Bosh::Dev::Bat::BoshCliSession.stub(:new).and_return(bosh_cli_session)
    end

    describe '#write' do
      it 'uses the command line tool to generate the manifest' do
        bosh_cli_session.should_receive(:run_bosh).with("aws generate micro_bosh 'fake_vpc_outfile_path' 'fake_route53_outfile_path'")
        subject.write
      end
    end
  end
end
