require 'spec_helper'

module Bosh::Director
  describe ReleaseJob do
    describe 'update' do
      subject(:release_job) { described_class.new(job_meta, release_model, release_dir, double(:logger).as_null_object) }
      let(:release_dir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(release_dir) }
      let(:release_model) { FactoryBot.create(:models_release) }
      let(:job_meta) do
        { 'name' => 'foo-job', 'version' => '1', 'sha1' => 'deadbeef', 'fingerprint' => 'bar' }
      end

      before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
      let(:blobstore) { instance_double('Bosh::Director::Blobstore::Client') }
      let(:job_tarball_path) { File.join(release_dir, 'jobs', 'foo-job.tgz') }

      let(:job_bits) { create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}}) }
      before { FileUtils.mkdir_p(File.dirname(job_tarball_path)) }

      before { allow(blobstore).to receive(:create).and_return('fake-blobstore-id') }

      context 'when a template already exists' do
        before do
          FactoryBot.create(:models_template,
            blobstore_id: 'original-blobstore-id',
            name: 'foo-job',
            version: '1',
            sha1: 'deadbeef',
            fingerprint: 'bar',
            release_id: release_model.id,
          )
        end

        it 'attempts to delete the existing blob from the blobstore' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to receive(:delete).with('original-blobstore-id')
          expect(blobstore).to receive(:create).and_return('fake-blobstore-id')

          saved_job = release_job.update

          expect(saved_job.name).to eq('foo-job')
          expect(saved_job.version).to eq('1')
          expect(saved_job.release).to eq(release_model)
          expect(saved_job.sha1).to eq('deadbeef')
          expect(saved_job.blobstore_id).to eq('fake-blobstore-id')
        end

        it 'does not bail if blobstore deletion fails' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to receive(:delete).and_raise Bosh::Director::Blobstore::BlobstoreError
          expect(blobstore).to receive(:create)

          saved_job = release_job.update

          expect(saved_job.blobstore_id).to eq('fake-blobstore-id')
        end
      end

      describe 'without existing blobstore_id' do
        it 'it associates a new blob with the template' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to_not receive(:delete)
          expect(blobstore).to receive(:create)

          saved_job = release_job.update

          expect(saved_job.blobstore_id).to eq('fake-blobstore-id')
        end
      end

      it 'should upload job bits to blobstore' do
        File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

        expect(blobstore).to receive(:create) do |f|
          f.rewind
          expect(::Digest::SHA1.hexdigest(f.read)).to eq(::Digest::SHA1.hexdigest(job_bits))

          ::Digest::SHA1.hexdigest(f.read)
        end

        expect(Models::Template.count).to eq(0)
        release_job.update

        job_model = Models::Template.first
        expect(job_model.name).to eq('foo-job')
        expect(job_model.version).to eq('1')
        expect(job_model.release).to eq(release_model)
        expect(job_model.sha1).to eq('deadbeef')
      end

      it 'should fail when it cannot extract job archive' do
        result = Bosh::Common::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Common::Exec).to receive(:sh).and_return(result)

        expect { release_job.update }.to raise_error(JobInvalidArchive)
      end

      it 'whines on missing manifest' do
        job_without_manifest =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}}, skip_manifest: true)

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_manifest) }

        expect { release_job.update }.to raise_error(JobMissingManifest)
      end

      it 'whines on inconsistent job name' do
        job_without_manifest =
          create_release_job('different-job-name', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}})

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_manifest) }

        expect { release_job.update }.to raise_error(JobInvalidName)
      end

      it 'whines on missing monit file' do
        job_without_monit =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}}, skip_monit: true)
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.update }.to raise_error(JobMissingMonit)
      end

      it 'does not whine when it has a foo.monit file' do
        job_without_monit =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}}, monit_file: 'foo.monit')

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.update }.to_not raise_error
      end

      it 'saves the templates hash in the template spec' do
        job_with_interesting_templates =
          create_release_job('foo-job', 'monit', {
            'template source path' => {'destination' => 'rendered template path', 'contents' => 'whatever'}
          }, monit_file: 'foo.monit')

        File.open(job_tarball_path, 'w') { |f| f.write(job_with_interesting_templates) }

        saved_template = release_job.update

        expect(saved_template.spec['templates']).to eq({'template source path' => 'rendered template path'})
      end

      it 'whines on missing template' do
        job_without_template =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}}, skip_templates: ['foo-erb'])

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_template) }

        expect { release_job.update }.to raise_error(JobMissingTemplateFile)
      end

      it 'does not whine when no packages are specified' do
        job_without_packages =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-renderd', 'contents' => 'bar'}},
                             manifest: {
              'name' => 'foo-job',
              'templates' => {}
            })
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_packages) }

        job = nil
        expect { job = release_job.update }.to_not raise_error
        expect(job.package_names).to eq([])
      end

      it 'whines when packages is not an array' do
        job_with_invalid_packages =
          create_release_job('foo-job', 'monit', { 'foo-erb' => { 'destination' => 'foo-rendered', 'contents' => 'bar'}},
                             manifest: {
              'name' => 'foo-job',
              'templates' => {},
              'packages' => 'my-awesome-package'
            })
        File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_packages) }

        expect { release_job.update }.to raise_error(JobInvalidPackageSpec)
      end

      context 'when job spec file includes provides' do
        it 'verifies it is an array' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'provides' => 'Invalid'
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of hashes' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'provides' => ['Invalid', 1]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies hash contains name and type' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'provides' => [{'name' => 'db'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies names are unique' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'provides' => [{'name' => 'db', 'type' => 'first'}, {'name' => 'db', 'type' => 'second'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(
            JobDuplicateLinkName,
            "Job 'foo-job' specifies duplicate provides link with name 'db'"
          )
        end

        it 'saves them on template' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'provides' => [{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect(Models::Template.count).to eq(0)
          release_job.update

          template = Models::Template.first
          expect(template.provides).to eq([{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}])
        end
      end

      context 'when job spec file includes consumes' do
        it 'verifies it is an array' do
          allow(blobstore).to receive(:create).and_return('fake-blobstore-id')

          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'consumes' => 'Invalid'
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of string' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'consumes' => ['Invalid', 1]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies hash contains name and type' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'consumes' => [{'name' => 'db'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies names are unique' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'consumes' => [{'name' => 'db', 'type' => 'one'}, {'name' => 'db', 'type' => 'two'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update }.to raise_error(
              JobDuplicateLinkName,
              "Job 'foo-job' specifies duplicate consumes link with name 'db'"
            )
        end

        it 'saves them on template' do
          job_with_invalid_spec = create_release_job('foo-job', 'monit', {},
                                                     manifest: {
              'name' => 'foo-job',
              'consumes' => [{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}]
            })
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect(Models::Template.count).to eq(0)
          release_job.update

          template = Models::Template.first
          expect(template.consumes).to eq([{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'} ])
        end
      end
    end
  end
end
