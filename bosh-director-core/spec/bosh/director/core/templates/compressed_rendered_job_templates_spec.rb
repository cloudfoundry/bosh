require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/director/core/templates/compressed_rendered_job_templates'
require 'bosh/director/core/templates/rendered_job_template'

module Bosh::Director::Core::Templates
  describe CompressedRenderedJobTemplates do
    subject { described_class.new('/tmp/file-path') }

    describe '#write' do
      let(:rendered_job_template) do
        instance_double(
          'Bosh::Director::Core::Templates::RenderedJobTemplate',
          name: 'job-template-name',
          monit: 'monit file contents',
          templates: [],
        )
      end

      before { allow(Dir).to receive(:mktmpdir).and_yield('/tmp/path/for/non-compressed/templates') }

      before { RenderedTemplatesWriter.stub(new: writer) }
      let(:writer) { instance_double('Bosh::Director::Core::Templates::RenderedTemplatesWriter') }

      before { Bosh::Director::Core::TarGzipper.stub(new: tar_gzipper) }
      let(:tar_gzipper) { instance_double('Bosh::Director::Core::TarGzipper') }

      it 'writes rendered templates to disk and then compresses them' do
        expect(writer).to receive(:write).with(
          [rendered_job_template], '/tmp/path/for/non-compressed/templates').ordered

        expect(tar_gzipper).to receive(:compress).with(
          '/tmp/path/for/non-compressed/templates', %w(.), '/tmp/file-path').ordered

        subject.write([rendered_job_template])
      end
    end

    describe '#contents' do
      include FakeFS::SpecHelpers

      before { Dir.mkdir('/tmp') }

      context 'when file exists' do
        before { File.open('/tmp/file-path', 'w') { |f| f.write('fake-content') } }

        it 'returns IO object for given path' do
          expect(subject.contents.readlines).to eq(['fake-content'])
        end
      end

      context 'when file does not exist' do
        it 'raises an error' do
          expect {
            subject.contents
          }.to raise_error(Errno::ENOENT, /file-path/)
        end
      end
    end

    describe '#sha1' do
      include FakeFS::SpecHelpers

      before { Dir.mkdir('/tmp') }

      context 'when file exists' do
        before { File.open('/tmp/file-path', 'w') { |f| f.write("fake-content\n") } }

        it 'returns sha1 of contents at given path' do
          expect(subject.sha1).to eq('ce0962ad2eeee3cab242191bc5ea6122c2ec8e36')
        end
      end

      context 'when file does not exist' do
        it 'raises an error' do
          expect {
            subject.sha1
          }.to raise_error(Errno::ENOENT, /file-path/)
        end
      end
    end
  end
end
