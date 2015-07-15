require 'spec_helper'

module Bosh::AwsCliPlugin
  describe BoshBootstrap do
    subject(:bootstrap) { described_class.new(director, s3, {}) }

    let(:s3) { instance_double('Bosh::AwsCliPlugin::S3') }

    let(:manifest) { instance_double('Bosh::AwsCliPlugin::BoshManifest',
                                     deployment_name: '',
                                     file_name: '').as_null_object }
    before { allow(BoshManifest).to receive(:new).and_return(manifest) }

    let(:director) { instance_double('Bosh::Cli::Client::Director',
                                     list_releases: [],
                                     list_stemcells: [],
                                     list_deployments: ['fake deployment']).as_null_object }
    before { allow(Bosh::Cli::Client::Director).to receive(:new).and_return(director) }

    let(:deployment_command) { instance_double('Bosh::Cli::Command::Deployment').as_null_object }
    before { allow(Bosh::Cli::Command::Deployment).to receive(:new).and_return(deployment_command) }

    let(:upload_command) { instance_double('Bosh::Cli::Command::Release::UploadRelease').as_null_object }
    before { allow(Bosh::Cli::Command::Release::UploadRelease).to receive(:new).and_return(upload_command) }

    let(:misc_command) { instance_double('Bosh::Cli::Command::Misc', options: {}).as_null_object }
    before { allow(Bosh::Cli::Command::Misc).to receive(:new).and_return(misc_command) }

    let(:login_command) { instance_double('Bosh::Cli::Command::Login', options: {}).as_null_object }
    before { allow(Bosh::Cli::Command::Login).to receive(:new).and_return(login_command) }

    describe '#start' do
      context 'stemcell exists on director' do
        before do
          allow(director).to receive(:list_stemcells).and_return(['fake stemcell'])
        end

        context 'release does not exist on dir director' do
          it 'downloads correct release version by correctly parsing Bosh::AwsCliPlugin::VERSION' do
            stub_const('Bosh::AwsCliPlugin::VERSION', '1.123.0')

            allow(bootstrap).to receive(:load_yaml_file)
            allow(bootstrap).to receive(:write_yaml)

            expect(s3).to receive(:copy_remote_file).with('bosh-jenkins-artifacts', 'release/bosh-123.tgz', 'bosh_release.tgz')

            bootstrap.start
          end
        end
      end

      context 'stemcell does not exist on director' do
        before do
          allow(director).to receive(:list_releases).and_return([{ 'name' => 'bosh' }])
          allow(Bosh::Stemcell::Archive).to receive(:new).and_return(archive)
          allow(Bosh::Cli::Command::Stemcell).to receive(:new).and_return(stemcell_command)
          allow(stemcell_command).to receive(:options=)
          allow(stemcell_command).to receive(:upload)
          allow(Bosh::Stemcell::ArchiveFilename).to receive(:new).and_return(archive_filename)
          allow(Bosh::Stemcell::Definition).to receive(:for).and_return(definition)
        end

        let(:definition) { instance_double('Bosh::Stemcell::Definition') }
        let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'fake-stemcell-archive-filename') }
        let(:archive) { instance_double('Bosh::Stemcell::Archive', name: 'fake-archive-name') }
        let(:stemcell_command) { instance_double('Bosh::Cli::Command::Stemcell') }

        context 'release exists on director' do
          it 'downloads correct stemcell version and uploads to director' do
            allow(bootstrap).to receive(:load_yaml_file)
            allow(bootstrap).to receive(:write_yaml)
            stemcell_path = 'fake-downloaded-path'
            expect(manifest).to receive(:stemcell_name=).with(archive.name)

            allow(s3).to receive(:copy_remote_file).and_return(stemcell_path)

            bootstrap.start

            expect(s3).to have_received(:copy_remote_file).with('bosh-jenkins-artifacts', 'bosh-stemcell/aws/fake-stemcell-archive-filename', 'bosh_stemcell.tgz')

            expect(Bosh::Stemcell::ArchiveFilename).to have_received(:new).with('latest', definition, 'bosh-stemcell', 'raw')
            expect(Bosh::Stemcell::Definition).to have_received(:for).with('aws', 'xen', 'ubuntu', 'trusty', 'go', true)
            expect(stemcell_command).to have_received(:upload).with(stemcell_path)
            expect(Bosh::Stemcell::Archive).to have_received(:new).with(stemcell_path)
          end

          context 'BOSH_OVERRIDE_LIGHT_STEMCELL_URL environment variable is set' do
            it 'uploads the stemcell pointed to by BOSH_OVERRIDE_LIGHT_STEMCELL_URL' do
              stemcell_path = 'fake-override-path'

              allow(ENV).to receive(:to_hash).and_return('BOSH_OVERRIDE_LIGHT_STEMCELL_URL' => stemcell_path)
              allow(bootstrap).to receive(:load_yaml_file)
              allow(bootstrap).to receive(:write_yaml)

              expect(manifest).to receive(:stemcell_name=).with(archive.name)

              bootstrap.start

              expect(stemcell_command).to have_received(:upload).with(stemcell_path)
              expect(Bosh::Stemcell::Archive).to have_received(:new).with(stemcell_path)
            end
          end
        end
      end
    end
  end
end
