require 'bosh/director/core/templates'
require 'fileutils'

module Bosh::Director::Core::Templates
  class RenderedTemplatesWriter
    def write(rendered_templates, output_dir)
      rendered_templates.each do |job_template|
        job_template_dir = File.join(output_dir, job_template.name)
        Dir.mkdir(job_template_dir)

        File.open(File.join(job_template_dir, 'monit'), 'w') do |f|
          f.write(job_template.monit)
        end

        job_template.templates.each do |file_template|
          file_template_dest = File.join(job_template_dir, file_template.dest_name)
          FileUtils.mkdir_p(File.dirname(file_template_dest))
          File.open(file_template_dest, 'w') do |f|
            f.write(file_template.contents)
          end
        end
      end
    end
  end
end
