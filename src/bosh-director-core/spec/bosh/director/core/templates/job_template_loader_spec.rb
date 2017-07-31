# encoding: UTF-8
# encoding is needed for correctly comparing expected ERB below
require 'spec_helper'
require 'bosh/director/core/templates/job_template_loader'
require 'bosh/director/core/templates/caching_job_template_fetcher'
require 'archive/tar/minitar'
require 'stringio'
require 'yaml'
require 'zlib'

# prevent using ASCII on ppc64le platform
Encoding.default_external = "UTF-8"

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
      tar.add_file('job.MF', { mode: '0644', mtime: 0 }) { |os, _| os.write(manifest.to_yaml) }
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

def create_job_tarball(name, monit, configuration_files, options = {})
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

  tmp_file = Tempfile.new('blob')
  File.open(tmp_file.path, 'w') { |f| f.write(ball) }

  tmp_file.path
end

module Bosh::Director::Core::Templates
  describe JobTemplateLoader do
    describe '#process' do
      subject(:job_template_loader) { JobTemplateLoader.new(logger, CachingJobTemplateFetcher.new) }
      let(:logger) { double('Logger', debug: nil) }
      let(:dns_encoder) { double('fake dns encoder') }

      it 'returns the jobs template erb objects' do
        tarball_path = create_job_tarball(
          'release-job-name',
          'monit file erb contents',
          { 'test' => {
            'destination' => 'test_dst',
            'contents' => 'test contents' }
          }
        )

        job = double('Bosh::Director::DeploymentPlan::Job',
          download_blob: tarball_path,
          name: 'plan-job-name',
          blobstore_id: 'blob-id'
        )

        generated_renderer = job_template_loader.process(job)

        expect(generated_renderer.monit_erb.erb.filename).to eq('plan-job-name/monit')
        expect(generated_renderer.monit_erb.erb.src).to eq ERB.new('monit file erb contents').src

        source_erb = generated_renderer.source_erbs.first
        expect(source_erb.src_name).to eq('test')
        expect(source_erb.dest_name).to eq('test_dst')
        expect(source_erb.erb.filename).to eq('plan-job-name/test')
        expect(source_erb.erb.src).to eq ERB.new('test contents').src
      end

      it 'returns only monit erb object when no other templates exist' do
        tarball_path = create_job_tarball('foo-release-job', 'monit file erb contents', {})

        job = double('Bosh::Director::DeploymentPlan::Job', download_blob: tarball_path, name: 'plan-job-name', blobstore_id: 'blob-id')

        generated_renderer = job_template_loader.process(job)

        expect(generated_renderer.monit_erb.erb.filename).to eq('plan-job-name/monit')
        expect(generated_renderer.monit_erb.erb.src).to eq ERB.new('monit file erb contents').src

        expect(generated_renderer.source_erbs).to eq([])
      end
    end
  end
end
