require 'spec_helper'
require 'bosh/director/core/templates/rendered_job_template'
require 'bosh/director/core/templates/rendered_file_template'
require 'bosh/director/core/templates/rendered_templates_writer'
require 'bosh/director/core/templates/rendered_templates_in_memory_tar_gzipper'
require 'tmpdir'

module Bosh::Director::Core::Templates
  describe RenderedTemplatesInMemoryTarGzipper do

    def write_and_explode_tar_file(contents, dest_dir)
      tarball_path = File.join(dest_dir, 'great_tarball.tar.gz')
      File.open(tarball_path, 'wb') { |f| f.write contents }
      `tar -xz -C #{dest_dir} -f #{tarball_path}`
    end

    describe '#produce_gzipped_tarball' do
      let(:rendered_file_template) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('myfiletemplate1.yml.erb', 'myfiletemplate1.yml', 'This is a great file')
      end

      let(:rendered_file_template_large_content) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('large_template.yml.erb', 'large_template.yml', "I am a very large file, ha ha ha\n"*10000)
      end

      let(:rendered_file_template_nested_destination) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('nested_template.yml.erb', 'level_1/level_2/level_3/nested_template.yml', 'I am a nested template')
      end

      let(:rendered_file_template_empty) do
        Bosh::Director::Core::Templates::RenderedFileTemplate.new('empty_template.yml.erb', 'empty_template.yml', '')
      end

      let(:rendered_job_template_1) do
        RenderedJobTemplate.new('myjob', 'monit', [rendered_file_template])
      end

      let(:rendered_job_template_2) do
        RenderedJobTemplate.new('mysecondjob', 'monit', [rendered_file_template_large_content])
      end

      context 'when passed rendered templates' do
        it 'returns a string of the targzip of these templates' do
          result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template_1])

          Dir.mktmpdir do |tmpdir|
            write_and_explode_tar_file(result, tmpdir)

            ls_result = `find #{tmpdir}`
            expect(ls_result).to include('myjob/myfiletemplate1.yml')
            expect(ls_result).to include('myjob/monit')
            expect(ls_result).to_not include('myfiletemplate1.yml.erb')
          end
        end

        it 'can handle large files' do
          result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template_2])

          Dir.mktmpdir do |tmpdir|
            write_and_explode_tar_file(result, tmpdir)

            ls_result = `find #{tmpdir}`
            expect(ls_result).to include('large_template.yml')
            expected_sha1 = Digest::SHA1.hexdigest( "I am a very large file, ha ha ha\n"*10000)

            myfile = File.join(tmpdir, 'mysecondjob', 'large_template.yml')
            actual_sha1 = Digest::SHA1.file(myfile).hexdigest

            expect(actual_sha1).to eq(expected_sha1)
          end
        end

        it 'preserves directory structure with multiple templates' do
          rendered_job_template_1 = RenderedJobTemplate.new('job_1', 'monit content 1', [rendered_file_template, rendered_file_template_large_content, rendered_file_template_nested_destination])
          rendered_job_template_2 = RenderedJobTemplate.new('job_2', 'monit content 2', [rendered_file_template, rendered_file_template_large_content, rendered_file_template_nested_destination])

          result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template_1, rendered_job_template_2])

          Dir.mktmpdir do |tmpdir|
            write_and_explode_tar_file(result, tmpdir)

            ls_result = `find #{tmpdir}`

            expect(ls_result).to include('job_1/monit')
            expect(ls_result).to include('job_2/monit')
            expect(ls_result).to include('job_1/large_template.yml')
            expect(ls_result).to include('job_2/large_template.yml')
            expect(ls_result).to include('job_1/myfiletemplate1.yml')
            expect(ls_result).to include('job_2/myfiletemplate1.yml')
            expect(ls_result).to include('job_1/level_1/level_2/level_3/nested_template.yml')
            expect(ls_result).to include('job_2/level_1/level_2/level_3/nested_template.yml')
          end
        end

        it 'can handle errands (monit files empty)' do
          rendered_job_template = RenderedJobTemplate.new('errand_job', '', [rendered_file_template])

          result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template])

          Dir.mktmpdir do |tmpdir|
            write_and_explode_tar_file(result, tmpdir)

            ls_result = `find #{tmpdir}`

            expect(ls_result).to include('errand_job/monit')

            monit_file = File.join(tmpdir, 'errand_job', 'monit')
            expect(File.size(monit_file)).to eq(0)
          end
        end

        it 'respects zero byte files' do
          rendered_job_template = RenderedJobTemplate.new('my_job', '', [rendered_file_template_empty])

          result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template])

          Dir.mktmpdir do |tmpdir|
            write_and_explode_tar_file(result, tmpdir)

            ls_result = `find #{tmpdir}`

            expect(ls_result).to include('my_job/empty_template.yml')

            template_file = File.join(tmpdir, 'my_job', 'empty_template.yml')
            expect(File.size(template_file)).to eq(0)
          end
        end

        context 'when rendered_job_template has no file templates' do
          let(:rendered_job_template) do
            RenderedJobTemplate.new('no_templates_job', 'monit', [])
          end

          it 'should return the compressed archive without errors' do
            result = RenderedTemplatesInMemoryTarGzipper.produce_gzipped_tarball([rendered_job_template])

            Dir.mktmpdir do |tmpdir|
              write_and_explode_tar_file(result, tmpdir)

              ls_result = `find #{tmpdir}`
              expect(ls_result).to include('no_templates_job/monit')
            end
          end
        end
      end
    end
  end
end
