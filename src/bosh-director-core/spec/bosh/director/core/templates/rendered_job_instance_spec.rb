require 'spec_helper'
require 'bosh/director/core/templates/rendered_job_instance'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/director/agent_client'
require 'securerandom'

module Bosh::Director::Core::Templates
  describe RenderedJobInstance do
    subject(:instance) { described_class.new(templates) }

    describe '#configuration_hash' do
      let(:templates) {
        [
          RenderedJobTemplate.new(
            'template-name1',
            'monit file contents 1',
            [
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                src_name: 'template-file1',
                dest_name: 'template-file1',
                contents: 'template file contents 1')
            ]
          ),
          RenderedJobTemplate.new(
            'template-name2',
            'monit file contents 2',
            [
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                src_name: 'template-file3',
                dest_name: 'template-file3',
                contents: 'template file contents 3'),
              instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                src_name: 'template-file2',
                dest_name: 'template-file2',
                contents: 'template file contents 2'),
            ]
          ),
        ]
      }

      it 'returns a sha1 checksum of all rendered template files for all job templates' do
        expect(instance.configuration_hash).to eq('c40a2263b628f1454eeab6d482a4c86c4d83eb53')
      end

      context 'when template has empty files' do
        let(:templates) {
          [
            RenderedJobTemplate.new(
              'template-name1',
              'monit file contents 1',
              [
                instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                  src_name: 'template-file1',
                  dest_name: 'template-file1',
                  contents: 'template file contents 1')
              ]
            )
          ]
        }

        let(:templates2) {
          [
            RenderedJobTemplate.new(
              'template-name1',
              'monit file contents 1',
              [
                instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                  src_name: 'template-file1',
                  dest_name: 'template-file1',
                  contents: 'template file contents 1')
              ]
            ),
            RenderedJobTemplate.new(
              'template-name2',
              '',
              [
                instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                  src_name: 'template-file1',
                  dest_name: 'template-file1',
                  contents: '')
              ]
            ),
          ]
        }

        it 'returns a different SHA' do
          expect(RenderedJobInstance.new(templates).configuration_hash).to_not eq(RenderedJobInstance.new(templates2).configuration_hash)
        end
      end

      context 'when job without templates is added' do
        let(:templates) {
          [
            RenderedJobTemplate.new(
              'template-name1',
              'monit file contents 1',
              [
                instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                  src_name: 'template-file1',
                  dest_name: 'template-file1',
                  contents: 'template file contents 1')
              ]
            )
          ]
        }

        let(:templates2) {
          [
            RenderedJobTemplate.new(
              'template-name1',
              'monit file contents 1',
              [
                instance_double('Bosh::Director::Core::Templates::RenderedFileTemplate',
                  src_name: 'template-file1',
                  dest_name: 'template-file1',
                  contents: 'template file contents 1')
              ]
            ),
            RenderedJobTemplate.new(
              'template-name2',
              '',
              []
            ),
          ]
        }

        it 'returns a different SHA' do
          expect(RenderedJobInstance.new(templates).configuration_hash).to_not eq(RenderedJobInstance.new(templates2).configuration_hash)
        end
      end
    end

    describe '#template_hashes' do
      let(:templates) {
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name1',
            template_hash: 'hash1',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name2',
            template_hash: 'hash2',
          ),
        ]
      }

      it 'returns a hash of job template names to sha1 checksums of the rendered job template files' do
        expect(instance.template_hashes).to eq('template-name1' => 'hash1', 'template-name2' => 'hash2')
      end
    end

    describe '#persist_on_blobstore' do
      let(:templates) {
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name1',
            template_hash: 'hash1',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'template-name2',
            template_hash: 'hash2',
          ),
        ]
      }

      def perform
        instance.persist_on_blobstore(blobstore)
      end

      let(:blobstore) { double('Bosh::Blobstore::BaseClient') }

      let(:templates) { [instance_double('Bosh::Director::Core::Templates::RenderedJobTemplate')] }

      before { allow(CompressedRenderedJobTemplates).to receive(:new).and_return(compressed_archive) }
      let(:compressed_archive) do
        instance_double(
          'Bosh::Director::Core::Templates::CompressedRenderedJobTemplates',
          write: nil,
          contents: nil,
          sha1: 'fakesha1',
        )
      end

      before { allow(blobstore).to receive(:create).and_return('fake-blobstore-id') }

      before { allow(Tempfile).to receive(:new).and_return(temp_file) }
      let(:temp_file) { instance_double('Tempfile', path: '/temp/archive/path.tgz', close!: nil) }

      it 'compresses the provided RenderedJobTemplate objects' do
        perform
        expect(CompressedRenderedJobTemplates).to have_received(:new).with('/temp/archive/path.tgz')
        expect(compressed_archive).to have_received(:write).with(templates)
      end

      it 'uploads the compressed archive to the blobstore after writing it' do
        compressed_archive_io = double('fake-compressed_archive_io')
        allow(compressed_archive).to receive(:contents).and_return(compressed_archive_io)
        expect(compressed_archive).to receive(:write).ordered
        expect(blobstore).to receive(:create).with(compressed_archive_io).ordered
        perform
      end

      it 'returns a rendered template archive' do
        rta = perform
        expect(rta.blobstore_id).to eq('fake-blobstore-id')
        expect(rta.sha1).to eq('fakesha1')
      end

      it 'closes temporary file after the upload' do
        expect(blobstore).to receive(:create).ordered
        expect(temp_file).to receive(:close!).ordered
        perform
      end

      it 'closes temporary file even when compression fails' do
        error = Exception.new('error')
        allow(compressed_archive).to receive(:write).and_raise(error)
        expect(temp_file).to receive(:close!).ordered
        expect { perform }.to raise_error(error)
      end

      it 'closes temporary file even when upload fails' do
        error = Exception.new('error')
        expect(blobstore).to receive(:create).and_raise(error)
        expect(temp_file).to receive(:close!).ordered
        expect { perform }.to raise_error(error)
      end
    end

    describe '#persist_through_agent' do
      let(:rendered_file_template_1) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('myfiletemplate1.yml.erb', 'myfiletemplate1.yml', 'This is the first great file')
      end

      let(:rendered_file_template_2) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('myfiletemplate2.yml.erb', 'myfiletemplate2.yml', 'This is a second great file')
      end

      let(:templates) {
        [
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'job-name1',
            monit: 'monit content 1',
            templates: [rendered_file_template_1],
            template_hash: 'hash1',
          ),
          instance_double(
            'Bosh::Director::Core::Templates::RenderedJobTemplate',
            name: 'job-name2',
            monit: 'monit content 2',
            templates: [rendered_file_template_2],
            template_hash: 'hash2',
          ),
        ]
      }
      let(:agent_client) { instance_double(Bosh::Director::AgentClient) }

      before do
        allow(SecureRandom).to receive(:uuid).and_return('random-blob-id')
        allow(agent_client).to receive(:upload_blob)
      end

      def perform
        instance.persist_through_agent(agent_client)
      end

      it 'compresses the provided RenderedJobTemplate objects in memory' do
        expect(RenderedTemplatesInMemoryTarGzipper).to receive(:produce_gzipped_tarball).with(templates).and_return('')
        perform
      end

      it 'calls agent client upload_blob action' do
        allow(Digest::SHA1).to receive(:hexdigest).and_return('fake-blob-sha1')
        allow(Base64).to receive(:encode64).and_return('base64-encoded-content')

        expect(agent_client).to receive(:upload_blob).with(
          'random-blob-id',
          'fake-blob-sha1',
          'base64-encoded-content'
        )
        perform
      end

      it 'returns a rendered template archive' do
        expect(RenderedTemplatesInMemoryTarGzipper).to receive(:produce_gzipped_tarball).with(templates).and_return('I am a gzipped tarball')
        rendered_templates_archive = perform
        expect(rendered_templates_archive.blobstore_id).to eq('random-blob-id')
        expect(rendered_templates_archive.sha1).to eq('391bd790a0fe025fc8ff01e337d1b8c9906c1394')
      end
    end
  end
end
