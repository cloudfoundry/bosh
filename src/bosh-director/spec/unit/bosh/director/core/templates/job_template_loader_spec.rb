require 'spec_helper'
require 'bosh/director/core/templates/job_template_loader'
require 'minitar'
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

  Minitar::Writer.open(io) do |tar|
    unless options[:skip_manifest]
      string_manifest = manifest.is_a?(String) ? manifest : manifest.to_yaml
      tar.add_file('job.MF', { mode: '0644', mtime: 0 }) { |os, _| os.write(string_manifest) }
    end
    unless options[:skip_monit]
      monit_file = options[:monit_file] ? options[:monit_file] : 'monit'
      tar.add_file(monit_file, { mode: '0644', mtime: 0 }) { |os, _| os.write(monit) }
    end
    if options[:properties_schema]
      tar.add_file('properties_schema.json', { mode: '0644', mtime: 0 }) { |os, _| os.write(options[:properties_schema].to_json) }
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
      let(:monit_erb) { instance_double(SourceErb) }
      let(:job_template_erb) { instance_double(SourceErb) }
      let(:fake_renderer) { instance_double(JobTemplateRenderer) }
      let(:job_model) { double('Bosh::Director::Models::Template') }
      let(:properties_schema) { nil }
      let(:job_name) { 'fake-job-name-1' }
      let(:configuration_files) do
        {
          'test' => {
          'destination' => 'test_dst',
          'contents' => 'test contents' }
        }
      end
      let(:tarball_path) do
        create_job_tarball(
          job_name,
          'monit file erb contents',
          tmp_file,
          configuration_files,
          properties_schema: properties_schema
        )
      end

      let(:job)do
        double('Bosh::Director::DeploymentPlan::Job',
          download_blob: tarball_path,
          name: job_name,
          blobstore_id: 'blob-id',
          release: release
        )
      end

      before do
        allow(job).to receive(:model).and_return(job_model)
      end

      after do
        tmp_file.unlink
      end

      it 'returns the jobs template erb objects' do
        expect(job_model).to receive(:spec).and_return({ "templates" => { "test" => "test_dst" } })

        expect(SourceErb).to receive(:new).with(
          'monit',
          'monit',
          'monit file erb contents',
          job_name,
        ).and_return(monit_erb)

        expect(SourceErb).to receive(:new).with(
          'test',
          'test_dst',
          'test contents',
          job_name
        ).and_return(job_template_erb)

        expect(JobTemplateRenderer).to receive(:new).with(
          instance_job: job,
          monit_erb: monit_erb,
          source_erbs: [job_template_erb],
          properties_schema: nil,
          logger: logger,
          link_provider_intents: link_provider_intents,
          dns_encoder: dns_encoder,
        ).and_return fake_renderer

        generated_renderer = job_template_loader.process(job)
        expect(generated_renderer).to eq(fake_renderer)
      end

      context 'when there are no other templates' do
        let(:configuration_files) { {} }

        it 'includes only monit erb object' do
          expect(job_model).to receive(:spec).and_return({ "templates" => {} })

          expect(SourceErb).to receive(:new).once.with(
            'monit',
            'monit',
            'monit file erb contents',
            job_name,
          ).and_return(monit_erb)

          expect(JobTemplateRenderer).to receive(:new).with(
            instance_job: job,
            monit_erb: monit_erb,
            source_erbs: [],
            properties_schema: nil,
            logger: logger,
            link_provider_intents: link_provider_intents,
            dns_encoder: dns_encoder,
          ).and_return fake_renderer

          generated_renderer = job_template_loader.process(job)
          expect(generated_renderer).to eq(fake_renderer)
        end
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

          expect(job).to receive(:model).and_return(job_model)
          expect(job_model).to receive(:spec).and_return({ "templates" => {} })

          job_template_renderer = job_template_loader.process(job)
          expect(job_template_renderer.source_erbs).to eq([])
        end
      end

      context 'when the job includes a properties schema' do
        let(:properties_schema) { {"properties_schema" => "yes"} }

        it 'creates the template renderer with the properties schema' do
          expect(job_model).to receive(:spec).and_return({ "templates" => { "test" => "test_dst" } })

          expect(JobTemplateRenderer).to receive(:new).with(
            instance_job: job,
            monit_erb: anything,
            source_erbs: anything,
            properties_schema: properties_schema,
            logger: logger,
            link_provider_intents: link_provider_intents,
            dns_encoder: dns_encoder,
          ).and_return fake_renderer

          generated_renderer = job_template_loader.process(job)
          expect(generated_renderer).to eq(fake_renderer)
        end
      end
    end
  end
end
