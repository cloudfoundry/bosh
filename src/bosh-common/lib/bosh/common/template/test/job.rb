require 'yaml'

module Bosh::Common::Template::Test
  class Job
    def initialize(release_path, name)
      @release_path = release_path
      @name = name
      @job_path = File.join(@release_path, 'jobs', @name)
      # raise "No such job at path: #{@job_path}" if !File.exist?(@job_path)
      spec_path = File.join(@job_path, 'spec')
      @spec = YAML.load(File.read(spec_path), aliases: true)
      @templates = @spec['templates']
    end

    def template(rendered_file_name)
      @templates.each_pair do |k, v|
        return Template.new(@spec, File.join(@job_path, 'templates', k)) if v == rendered_file_name
      end
      raise "Template for rendered path filename not found: #{rendered_file_name}. Possible values are: [#{@templates.values.join(', ')}]"
    end
  end
end
