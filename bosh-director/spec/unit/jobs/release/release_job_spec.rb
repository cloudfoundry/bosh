require 'spec_helper'
require 'support/release_helper'

module Bosh::Director
  describe ReleaseJob do
    describe 'create jobs' do
      subject(:release_job) { described_class.new(job_meta, release_model, release_dir, packages, double(:logger).as_null_object) }
      let(:release_dir) { Dir.mktmpdir }
      after { FileUtils.rm_rf(release_dir) }
      let(:release_model) { Models::Release.make }
      let(:job_meta) { {'name' => 'foo', 'version' => '1', 'sha1' => 'deadbeef'} }
      let(:packages) { [] }

      before { allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore) }
      let(:blobstore) { instance_double('Bosh::Blobstore::BaseClient') }
      let(:job_tarball_path) { File.join(release_dir, 'jobs', 'foo.tgz') }

      let(:job_bits) { create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}) }
      before { FileUtils.mkdir_p(File.dirname(job_tarball_path)) }

      before { allow(blobstore).to receive(:create).and_return('fake-blobstore-id') }

      it 'should create a proper template and upload job bits to blobstore' do
        File.open(job_tarball_path, 'w') { |f| f.write(job_bits) }

        expect(blobstore).to receive(:create) do |f|
          f.rewind
          expect(Digest::SHA1.hexdigest(f.read)).to eq(Digest::SHA1.hexdigest(job_bits))

          Digest::SHA1.hexdigest(f.read)
        end

        expect(Models::Template.count).to eq(0)
        release_job.create

        template = Models::Template.first
        expect(template.name).to eq('foo')
        expect(template.version).to eq('1')
        expect(template.release).to eq(release_model)
        expect(template.sha1).to eq('deadbeef')
      end

      it 'should fail if cannot extract job archive' do
        result = Bosh::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        expect { release_job.create }.to raise_error(JobInvalidArchive)
      end

      it 'whines on missing manifest' do
        job_without_manifest =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_manifest: true)

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_manifest) }

        expect { release_job.create }.to raise_error(JobMissingManifest)
      end

      it 'whines on missing monit file' do
        job_without_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_monit: true)
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.create }.to raise_error(JobMissingMonit)
      end

      it 'does not whine when it has a foo.monit file' do
        job_without_monit =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, monit_file: 'foo.monit')

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_monit) }

        expect { release_job.create }.to_not raise_error
      end

      it 'whines on missing template' do
        job_without_template =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}}, skip_templates: ['foo'])

        File.open(job_tarball_path, 'w') { |f| f.write(job_without_template) }

        expect { release_job.create }.to raise_error(JobMissingTemplateFile)
      end

      it 'does not whine when no packages are specified' do
        job_without_packages =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}},
            manifest: { 'name' => 'foo', 'templates' => {} })
        File.open(job_tarball_path, 'w') { |f| f.write(job_without_packages) }

        job = nil
        expect { job = release_job.create }.to_not raise_error
        expect(job.package_names).to eq([])
      end

      it 'whines when packages is not an array' do
        job_with_invalid_packages =
          create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}},
            manifest: { 'name' => 'foo', 'templates' => {}, 'packages' => 'my-awesome-package' })
        File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_packages) }

        expect { release_job.create }.to raise_error(JobInvalidPackageSpec)
      end

      it 'throws error if package is not in the array' do
        job_with_missing_packages =
            create_job('foo', 'monit', {'foo' => {'destination' => 'foo', 'contents' => 'bar'}},
                       manifest: { 'name' => 'foo', 'templates' => {}, 'packages' =>  ['some_missing_package']  })
        File.open(job_tarball_path, 'w') { |f| f.write(job_with_missing_packages) }

        release_job.packages = { 'some_other_package_name' => {name: 'some other package name'}}

        expect { release_job.create }.to raise_error(JobMissingPackage)
      end

      context 'when job spec file includes provides' do
        it 'verifies it is an array' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => 'Invalid'})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.create }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of string' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'provides' => ['Invalid', 1]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.create }.to raise_error(JobInvalidLinkSpec)
        end
      end

      context 'when job spec file includes requires' do
        it 'verifies it is an array' do
          allow(blobstore).to receive(:create).and_return('fake-blobstore-id')

          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'requires' => 'Invalid'})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.create }.to raise_error(JobInvalidLinkSpec)
        end

        it 'verifies that it is an array of string' do
          job_with_invalid_spec = create_job('foo', 'monit', {}, manifest: {'requires' => ['Invalid', 1]})
          File.open(job_tarball_path, 'w') { |f| f.write(job_with_invalid_spec) }

          expect { release_job.create }.to raise_error(JobInvalidLinkSpec)
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
