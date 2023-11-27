require 'spec_helper'
require 'bosh/director/core/templates/job_template_loader'
require 'archive/tar/minitar'
require 'stringio'
require 'yaml'
require 'zlib'
require 'tempfile'

def gzip(string)
  result = StringIO.new
  zio = Zlib::GzipWriter.new(result, nil, nil)
  zio.mtime = 1
  zio.write(string)
  zio.close
  result.string
end

def write_tar(configuration_files, manifest, monit, options)
  io = StringIO.new

  Archive::Tar::Minitar::Writer.open(io) do |tar|
    unless options[:skip_manifest]
      string_manifest = manifest.is_a?(String) ? manifest : manifest.to_yaml
      tar.add_file('job.MF', { mode: '0644', mtime: 0 }) { |os, _| os.write(string_manifest) }
    end
    unless options[:skip_monit]
      monit_file = options[:monit_file] ? options[:monit_file] : 'monit'
      tar.add_file(monit_file, { mode: '0644', mtime: 0 }) { |os, _| os.write(monit) }
    end

    tar.mkdir('templates', { mode: '0755', mtime: 0 })
    configuration_files.each do |path, configuration_file|
      unless options[:skip_templates] && options[:skip_templates].include?(path)
        tar.add_file("templates/#{path}", { mode: '0644', mtime: 0 }) do |os, _|
          os.write(configuration_file['contents'])
        end
      end
    end
  end
  io.close
  io
end

def create_job_tarball(name, monit, tmp_file, configuration_files, options = {})
  manifest = {
    'name' => name,
    'templates' => {},
    'packages' => []
  }

  configuration_files.each do |path, configuration_file|
    manifest['templates'][path] = configuration_file['destination']
  end

  io = write_tar(configuration_files, manifest, monit, options)
  ball = gzip(io.string)

  File.open(tmp_file.path, 'w') { |f| f.write(ball) }

  tmp_file.path
end

module Bosh::Director::Core::Templates
  describe JobTemplateLoader do
    describe '#process' do
      subject(:job_template_loader) do
        JobTemplateLoader.new(logger, TemplateBlobCache.new, link_provider_intents, dns_encoder)
      end

      let(:logger) { double('Logger', debug: nil) }
      let(:link_provider_intents) { [] }
      let(:dns_encoder) { double('fake dns encoder') }
      let(:release) {double('Bosh::Director::DeploymentPlan::ReleaseVersion', name: 'fake-release-name', version:'0.1')}
      let(:tmp_file) { Tempfile.new('blob') }

      after :each do
        tmp_file.unlink
      end

      it 'returns the jobs template erb objects' do
        tarball_path = create_job_tarball(
          'fake-job-name-1',
          'monit file erb contents',
          tmp_file,
          { 'test' => {
            'destination' => 'test_dst',
            'contents' => 'test contents' }
          }
        )

        job = double('Bosh::Director::DeploymentPlan::Job',
          download_blob: tarball_path,
          name: 'fake-job-name-1',
          blobstore_id: 'blob-id',
          release: release
        )

        job_model = double('Bosh::Director::Models::Template')
        expect(job).to receive(:model).and_return(job_model)
        expect(job_model).to receive(:spec).and_return({ "templates" => { "test" => "test_dst" } })

        monit_erb = instance_double(SourceErb)
        job_template_erb = instance_double(SourceErb)
        fake_renderer = instance_double(JobTemplateRenderer)

        expect(SourceErb).to receive(:new).with(
          'monit',
          'monit',
          'monit file erb contents',
          'fake-job-name-1',
        ).and_return(monit_erb)

        expect(SourceErb).to receive(:new).with(
          'test',
          'test_dst',
          'test contents',
          'fake-job-name-1'
        ).and_return(job_template_erb)

        expect(JobTemplateRenderer).to receive(:new).with(
          instance_job: job,
          monit_erb: monit_erb,
          source_erbs: [job_template_erb],
          logger: logger,
          link_provider_intents: link_provider_intents,
          dns_encoder: dns_encoder,
        ).and_return fake_renderer

        generated_renderer = job_template_loader.process(job)
        expect(generated_renderer).to eq(fake_renderer)
      end

      it 'includes only monit erb object when no other templates exist' do
        tarball_path = create_job_tarball('fake-job-name-2', 'monit file erb contents', tmp_file, {})

        job = double(
          'Bosh::Director::DeploymentPlan::Job',
          download_blob: tarball_path,
          name: 'fake-job-name-2',
          blobstore_id: 'blob-id',
          release: release,
        )

        job_model = double('Bosh::Director::Models::Template')
        expect(job).to receive(:model).and_return(job_model)
        expect(job_model).to receive(:spec).and_return({ "templates" => {} })

        monit_erb = instance_double(SourceErb)
        fake_renderer = instance_double(JobTemplateRenderer)

        expect(SourceErb).to receive(:new).once.with(
          'monit',
          'monit',
          'monit file erb contents',
          'fake-job-name-2',
        ).and_return(monit_erb)

        expect(JobTemplateRenderer).to receive(:new).with(
          instance_job: job,
          monit_erb: monit_erb,
          source_erbs: [],
          logger: logger,
          link_provider_intents: link_provider_intents,
          dns_encoder: dns_encoder,
        ).and_return fake_renderer

        generated_renderer = job_template_loader.process(job)
        expect(generated_renderer).to eq(fake_renderer)
      end

      context 'when the job manifest uses yaml anchors' do
        it 'parses the anchors correctly' do
          manifest = <<~EOF
            ---
            bogus_key: &empty_hash {}
            name: test-job-name
            templates: *empty_hash
            packages: []
          EOF
          tarball = write_tar([], manifest, "", {})
          tgz = gzip(tarball.string)

          File.open(tmp_file.path, 'w') { |f| f.write(tgz) }

          job = double('Bosh::Director::DeploymentPlan::Job',
            download_blob: tmp_file.path,
            name: 'test-job-name',
            blobstore_id: 'blob-id',
            release: release,
            model: double('Bosh::Director::Models::Template', provides: [])
          )

          job_model = double('Bosh::Director::Models::Template')
          expect(job).to receive(:model).and_return(job_model)
          expect(job_model).to receive(:spec).and_return({ "templates" => {} })

          job_template_renderer = job_template_loader.process(job)
          expect(job_template_renderer.source_erbs).to eq([])
        end
      end
    end
  end
end
