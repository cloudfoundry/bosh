require 'spec_helper'
require 'support/release_helper'

module Bosh::Director
  describe ReleaseJob do

    describe 'update' do
      subject(:release_job) { described_class.new(job_meta, release_model, release_dir, double(:logger).as_null_object) }
      let(:release_dir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(release_dir) }
      let(:release_model) { Models::Release.make }
      let(:job_meta) { {'name' => 'foo', 'version' => '1', 'sha1' => 'deadbeef'} }

      before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
      let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
      let(:job_tarball_path) { File.join(release_dir, 'jobs', 'foo.tgz') }

      let(:job_bits) { create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}) }
      before { FileUtils.mkdir_p(File.dirname(job_tarball_path)) }

      before { allow(blobstore).to receive(:create).and_return('fake-blobstore-id') }
      let(:template) { Models::Template.new() }

      describe 'with existing blobstore_id' do
        before do
          template.blobstore_id = 'original-blobstore-id'
        end

        it 'attempts to delete the existing blob from the blobstore' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to receive(:delete).with('original-blobstore-id')
          expect(blobstore).to receive(:create).and_return('fake-blobstore-id')

          saved_template = release_job.update(template)

          expect(saved_template.name).to eq('foo')
          expect(saved_template.version).to eq('1')
          expect(saved_template.release).to eq(release_model)
          expect(saved_template.sha1).to eq('deadbeef')
          expect(saved_template.blobstore_id).to eq('fake-blobstore-id')
        end

        it 'does not bail if blobstore deletion fails' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to receive(:delete).and_raise Bosh::Blobstore::BlobstoreError
          expect(blobstore).to receive(:create)

          saved_template = release_job.update(template)

          expect(saved_template.blobstore_id).to eq('fake-blobstore-id')
        end
      end

      describe 'without existing blobstore_id' do
        it 'it associates a new blob with the template' do
          File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

          expect(blobstore).to_not receive(:delete)
          expect(blobstore).to receive(:create)

          saved_template = release_job.update(template)

          expect(saved_template.blobstore_id).to eq('fake-blobstore-id')
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
        release_job.update(template)

        template = Models::Template.first
        expect(template.name).to eq('foo')
        expect(template.version).to eq('1')
        expect(template.release).to eq(release_model)
        expect(template.sha1).to eq('deadbeef')
      end

      it 'should fail if cannot extract job archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        expect { release_job.update(template) }.to raise_error(JobInvalidArchive)
      end

      it 'whines on missing manifest' do
        job_without_manifest =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_manifest: true)

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_manifest) }

        expect { release_job.update(template) }.to raise_error(JobMissingManifest)
      end

      it 'whines on missing monit file' do
        job_without_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_monit: true)
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.update(template) }.to raise_error(JobMissingMonit)
      end

      it 'does not whine when it has a foo.monit file' do
        job_without_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, monit_file: 'foo.monit')

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.update(template) }.to_not raise_error
      end

      it 'saves the templates hash on the template' do
        job_with_interesting_templates =
          create_job('foo', 'monit', {
            'template source path' => {'destination' => 'rendered template path', 'contents' => 'whatever'}
          }, monit_file: 'foo.monit')

        File.open(job_tarball_path, 'w') { |f| f.write(job_with_interesting_templates) }

        saved_template = release_job.update(template)

        expect(saved_template.templates).to eq({'template source path' => 'rendered template path'})
      end

      it 'whines on missing template' do
        job_without_template =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_templates: ['foo'])

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_template) }

        expect { release_job.update(template) }.to raise_error(JobMissingTemplateFile)
      end

      it 'does not whine when no packages are specified' do
        job_without_packages =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}},
            manifest: { 'name' => 'foo', 'templates' => {} })
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_packages) }

        job = nil
        expect { job = release_job.update(template) }.to_not raise_error
        expect(job.package_names).to eq([])
      end

      it 'whines when packages is not an array' do
        job_with_invalid_packages =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}},
            manifest: { 'name' => 'foo', 'templates' => {}, 'packages' => 'my-awesome-package' })
        File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_packages) }

        expect { release_job.update(template) }.to raise_error(JobInvalidPackageSpec)
      end

      context 'when job spec file includes provides' do
        it 'verifies it is an array' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => 'Invalid'})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of hashes' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => ['Invalid', 1]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies hash contains name and type' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => [{'name' => 'db'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies names are unique' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => [{'name' => 'db', 'type' => 'first'}, {'name' => 'db', 'type' => 'second'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(
            JobDuplicateLinkName,
            "Job 'foo' 'provides' specifies links with duplicate name 'db'"
          )
        end

        it 'saves them on template' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => [{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect(Models::Template.count).to eq(0)
          release_job.update(template)

          template = Models::Template.first
          expect(template.provides).to eq([{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}])
        end
      end

      context 'when job spec file includes consumes' do
        it 'verifies it is an array' do
          allow(blobstore).to receive(:create).and_return('fake-blobstore-id')

          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'consumes' => 'Invalid'})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of string' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'consumes' => ['Invalid', 1]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies hash contains name and type' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'consumes' => [{'name' => 'db'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies names are unique' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'consumes' => [{'name' => 'db', 'type' => 'one'}, {'name' => 'db', 'type' => 'two'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.update(template) }.to raise_error(
              JobDuplicateLinkName,
              "Job 'foo' 'consumes' specifies links with duplicate name 'db'"
            )
        end

        it 'saves them on template' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'consumes' => [{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'}]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect(Models::Template.count).to eq(0)
          release_job.update(template)

          template = Models::Template.first
          expect(template.consumes).to eq([{'name' => 'db1', 'type' =>'db'}, {'name' => 'db2', 'type' =>'db'} ])
        end
      end
    end

    def create_job(name, monit, configuration_files, options = { })
      io = StringIO.new

      manifest = {
        'name' => name,
        'templates' => {},
        'packages' => []
      }.merge(options.fetch(:manifest, {}))

      configuration_files.each do |path, configuration_file|
        manifest['templates'][path] = configuration_file['destination']
      end

      Archive::Tar::Minitar::Writer.open(io) do |tar|
        manifest = options[:manifest] if options[:manifest]
        unless options[:skip_manifest]
          tar.add_file('job.MF', {:mode => '0644', :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
        end
        unless options[:skip_monit]
          monit_file = options[:monit_file] ? options[:monit_file] : 'monit'
          tar.add_file(monit_file, {:mode => '0644', :mtime => 0}) { |os, _| os.write(monit) }
        end

        tar.mkdir('templates', {:mode => '0755', :mtime => 0})
        configuration_files.each do |path, configuration_file|
          unless options[:skip_templates] && options[:skip_templates].include?(path)
            tar.add_file("templates/#{path}", {:mode => '0644', :mtime => 0}) do |os, _|
              os.write(configuration_file['contents'])
            end
          end
        end
      end

      io.close

      gzip(io.string)
    end
  end
end
