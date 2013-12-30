require 'spec_helper'

describe Bosh::Aws::BoshBootstrap do
  subject(:bootstrap) { described_class.new(director, s3, {}) }

  let(:s3) { instance_double('Bosh::Aws::S3') }

  let(:manifest) { instance_double('Bosh::Aws::BoshManifest',
                                   deployment_name: '',
                                   file_name: '').as_null_object }
  before { allow(Bosh::Aws::BoshManifest).to receive(:new).and_return(manifest) }

  let(:director) { instance_double('Bosh::Cli::Client::Director',
                                   list_releases: [],
                                   list_stemcells: ['fake stemcell'],
                                   list_deployments: ['fake deployment']).as_null_object }
  before { allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director) }

  let(:deployment_command) { instance_double('Bosh::Cli::Command::Deployment').as_null_object }
  before { allow(Bosh::Cli::Command::Deployment).to receive(:new).and_return(deployment_command) }

  let(:release_command) { instance_double('Bosh::Cli::Command::Release').as_null_object }
  before { allow(Bosh::Cli::Command::Release).to receive(:new).and_return(release_command) }

  let(:misc_command) { instance_double('Bosh::Cli::Command::Misc', options: {}).as_null_object }
  before { allow(Bosh::Cli::Command::Misc).to receive(:new).and_return(misc_command) }

  describe '#start' do
    it 'downloads correct release version by correctly parsing Bosh::Aws::VERSION' do
      stub_const('Bosh::Aws::VERSION', '1.123.0')

      allow(bootstrap).to receive(:load_yaml_file)
      allow(bootstrap).to receive(:write_yaml)

      expect(s3).to receive(:copy_remote_file).with('bosh-jenkins-artifacts', 'release/bosh-123.tgz', 'bosh_release.tgz')

      bootstrap.start
    end
  end
end
