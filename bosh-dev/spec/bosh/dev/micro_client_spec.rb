require 'spec_helper'
require 'bosh/dev/micro_client'
require 'bosh/stemcell/archive'
require 'fileutils'

module Bosh::Dev
  describe MicroClient do
    subject(:micro_client) { described_class.new }

    before { BoshCliSession.stub(new: cli) }
    let(:cli) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: nil) }

    describe '#deploy' do
      include FakeFS::SpecHelpers

      it 'sets the deployment and then runs a micro deploy using the cli' do
        manifest_path = '/path/to/fake-manifest.yml'

        FileUtils.mkdir_p('/path/to')

        stemcell_archive = instance_double(
          'Bosh::Stemcell::Archive',
          name: 'fake-stemcell',
          version: '008',
          path: '/path/to/fake-stemcell-008.tgz',
        )

        cli.should_receive(:run_bosh).
          with('micro deployment /path/to/fake-manifest.yml').
          ordered

        deploy_pwd = nil

        cli.should_receive(:run_bosh).
          with('micro deploy /path/to/fake-stemcell-008.tgz --update-if-exists').
          ordered { deploy_pwd = Dir.pwd }

        micro_client.deploy(manifest_path, stemcell_archive)

        expect(deploy_pwd).to eq('/path/to')
      end
    end
  end
end
