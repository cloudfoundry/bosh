require 'spec_helper'
require 'bosh/dev/aws/bat_deployment_manifest'
require 'bosh/stemcell/archive'

module Bosh::Dev::Aws
  describe BatDeploymentManifest do
    subject { described_class.new(env, 'manual', bosh_cli_session, stemcell_archive) }
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

    before { allow(Bosh::Dev::Aws::Receipts).to receive(:new).and_return(receipts) }

    its(:net_type) { should eq('manual') }

    describe '#write' do
      before do
        allow(bosh_cli_session).to receive(:run_bosh)
        allow(YAML).to receive(:load_file).with('bat.yml').and_return({
          'properties' => {
            'networks' => [
              {
                'type' => 'manual',
              },
            ],
          },
        })
      end

      it 'uses the command line tool to generate the manifest' do
        expect(bosh_cli_session).to receive(:run_bosh).with(
          "aws generate bat 'fake_vpc_outfile_path' 'fake_route53_outfile_path' '13' 'stemcell-name'")
        subject.write
      end

      it 'requires the net type to match the manifest' do
        expect { described_class.new(env, 'manual', bosh_cli_session, stemcell_archive).write }.not_to raise_error
        expect { described_class.new(env, 'dynamic', bosh_cli_session, stemcell_archive).write }.to raise_error
      end
    end
  end
end
