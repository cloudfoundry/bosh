require 'spec_helper'
require 'bosh/deployer/microbosh_job_instance'
require 'logger'

require 'bosh/director/core/templates/rendered_templates_archive'

module Bosh::Deployer
  describe MicroboshJobInstance do

    let(:mbus) { 'https://fake-user:fake-password@0.0.0.0:6868' }
    let(:bosh_ip) { '192.0.2.55' }
    let(:logger) { instance_double('Logger', debug: nil) }
    subject { MicroboshJobInstance.new(bosh_ip, mbus, logger) }

    describe '#render_templates' do
      let(:blobstore) { instance_double('Bosh::Blobstore::DavBlobstoreClient') }
      let(:job_template) { instance_double('Bosh::Deployer::JobTemplate') }
      let(:loader) { instance_double('Bosh::Director::Core::Templates::JobTemplateLoader') }
      let(:rendered_templates_archive) do
        instance_double(
          'Bosh::Director::Core::Templates::RenderedTemplatesArchive',
          spec: 'fake-archive-spec',
        )
      end
      let(:rendered_job_instance) do
        instance_double(
          'Bosh::Director::Core::Templates::RenderedJobInstance',
          persist: rendered_templates_archive,
          configuration_hash: 'fake-config-sha1',
        )
      end
      let(:job_instance_renderer) do
        instance_double(
          'Bosh::Director::Core::Templates::JobInstanceRenderer',
          render: rendered_job_instance,
        )
      end
      before do
        allow(Bosh::Blobstore::DavBlobstoreClient).to receive(:new).and_return(blobstore)
        allow(JobTemplate).to receive(:new).and_return(job_template)

        allow(Bosh::Director::Core::Templates::JobTemplateLoader).
          to receive(:new).and_return(loader)

        allow(Bosh::Director::Core::Templates::JobInstanceRenderer).
          to receive(:new).and_return(job_instance_renderer)
      end

      let(:spec) do
        {
          'job' => {
            'templates' => [
              {
                'name' => 'fake-job-template-name'
              }
            ]
          }
        }
      end

      it 'creates a dav blobstore pointing at the agent' do
        subject.render_templates(spec)
        blobstore_options = {
          'endpoint' => 'https://192.0.2.55:6868/blobs',
          'user' => 'fake-user',
          'password' => 'fake-password',
          'ssl_no_verify' => true,
        }
        expect(Bosh::Blobstore::DavBlobstoreClient).to have_received(:new).with(blobstore_options)
      end

      it 'create job templates from spec' do
        subject.render_templates(spec)
        expect(JobTemplate).to have_received(:new).with(spec['job']['templates'].first, blobstore)
      end

      it 'renders the rendered templates' do
        subject.render_templates(spec)
        expect(job_instance_renderer).to have_received(:render).with(spec)
      end

      it 'persists the rendered templates' do
        subject.render_templates(spec)
        expect(rendered_job_instance).to have_received(:persist).with(blobstore)
      end

      it 'returns an updated spec with configuration_hash and rendered_templates_archvie' do
        expected_spec = {
          'job' => {
            'templates' => [
              {
                'name' => 'fake-job-template-name'
              }
            ]
          },
          'rendered_templates_archive' => 'fake-archive-spec',
          'configuration_hash' => 'fake-config-sha1',
        }

        expect(subject.render_templates(spec)).to eq(expected_spec)
      end

      context 'when render raises a FetchError' do
        before do
          allow(job_instance_renderer).to receive(:render).and_raise(JobTemplate::FetchError)
        end

        it 'returns the original spec without rendering' do
          expect(subject.render_templates(spec)).to eq(spec)
        end
      end
    end
  end
end
