# encoding: UTF-8
# encoding is needed for correctly comparing expected ERB below
require 'spec_helper'
require 'bosh/director/core/templates/job_template_loader'
require 'archive/tar/minitar'
require 'stringio'
require 'yaml'
require 'zlib'

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

def create_job(name, monit, configuration_files, options = {})
  manifest = {
    'name' => name,
    'templates' => {},
    'packages' => []
  }

  configuration_files.each do |path, configuration_file|
    manifest['templates'][path] = configuration_file['destination']
  end

  io = write_tar(configuration_files, manifest, monit, options)

  gzip(io.string)
end

module Bosh::Director::Core::Templates
  describe JobTemplateLoader do
    describe '#process' do
      subject(:job_template_loader) { JobTemplateLoader.new(logger) }
      let(:logger) { double('Logger') }

      it 'returns the jobs template erb objects' do
        template_contents = create_job('foo', 'monit file',
                                       { 'test' => {
                                         'destination' => 'test_dst',
                                         'contents' => 'test contents' }
                                       })

        tmp_file = Tempfile.new('blob')
        File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
        job_template = double('Bosh::Director::DeploymentPlan::Template', download_blob: tmp_file.path, name: 'foo')

        container = job_template_loader.process(job_template)

        expect(container.monit_template.filename).to eq('foo/monit')
        expect(container.monit_template.src).to eq ERB.new('monit file').src

        src_template = container.templates.first
        expect(src_template.src_name).to eq('test')
        expect(src_template.dest_name).to eq('test_dst')
        expect(src_template.erb_file.filename).to eq('foo/test')
        expect(src_template.erb_file.src).to eq ERB.new('test contents').src
      end

      it 'returns only monit erb object when no other templates exist' do
        template_contents = create_job('foo', 'monit file', {})

        tmp_file = Tempfile.new('blob')
        File.open(tmp_file.path, 'w') { |f| f.write(template_contents) }
        job_template = double('Bosh::Director::DeploymentPlan::Template', download_blob: tmp_file.path, name: 'foo')

        container = job_template_loader.process(job_template)

        expect(container.monit_template.filename).to eq('foo/monit')
        expect(container.monit_template.src).to eq ERB.new('monit file').src

        expect(container.templates).to eq([])
      end
    end
  end
end
