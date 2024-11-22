require 'rubygems/package'
require 'zlib'
require 'fileutils'

module Bosh::Director::Core::Templates
  class RenderedTemplatesInMemoryTarGzipper

    CREATED_FILES_PERMISSIONS = 0644

    def self.produce_gzipped_tarball(rendered_job_templates)
      tarfile = StringIO.new('')

      Gem::Package::TarWriter.new(tarfile) do |tar|
        rendered_job_templates.each do |rendered_job_template|
          job_name = rendered_job_template.name

          monit_content = rendered_job_template.monit
          monit_path = File.join(job_name, 'monit')

          tar.add_file monit_path, CREATED_FILES_PERMISSIONS do |file|
            file.write(monit_content)
          end

          rendered_job_template.templates.each do |rendered_file_template|
            template_path = File.join(job_name, rendered_file_template.dest_filepath)

            tar.add_file template_path, CREATED_FILES_PERMISSIONS do |tf|
              tf.write(rendered_file_template.contents)
            end
          end
        end
      end

      tarfile.close
      compress_in_memory(tarfile.string)
    end

    private

    def self.compress_in_memory(tar_contents)
      gz = StringIO.new('')
      z = Zlib::GzipWriter.new(gz)
      z.write tar_contents
      z.close

      gz.close
      gz.string
    end
  end
end
