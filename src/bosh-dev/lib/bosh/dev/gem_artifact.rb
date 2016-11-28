require 'bosh/dev/command_helper'

module Bosh::Dev
  class GemArtifact
    include CommandHelper
    def initialize(component, pipeline_prefix, build_number, logger)
      @component = component
      @pipeline_prefix = pipeline_prefix
      @build_number = build_number
      @logger = logger
    end

    def name
      @component.dot_gem
    end

    def promote
      ensure_rubygems_crendentials!

      dot_gem_path = "#{tmp_download_dir}/#{@component.dot_gem}"
      FileUtils.rm(dot_gem_path) if File.exists?(dot_gem_path)

      source = "#{@pipeline_prefix}gems/gems/#{@component.dot_gem}"
      stdout, stderr, status = exec_cmd("s3cmd --verbose get #{source} #{tmp_download_dir}")
      raise "Failed downloading #{source}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

      Bundler.with_clean_env do
        stdout, stderr, status = exec_cmd("gem push #{dot_gem_path}")
        raise "Failed pushing gem #{dot_gem_path}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?
      end

      @logger.info("Promoted: #{@component.dot_gem}")
    rescue
      @logger.warn("Failed promoting: #{@component.dot_gem}")
      raise
    end

    def promoted?
      Bundler.with_clean_env do
        escaped_gem_name = Regexp.escape(@component.name)

        # get remote gems with the name regex and all their versions
        stdout, stderr, status = exec_cmd("gem query -r -a -n #{escaped_gem_name}")
        raise "Failed querying gems with name #{@component.name}: stdout: '#{stdout}', stderr: '#{stderr}'" unless status.success?

        # remote gem list starts on line 4
        lines = stdout.chomp.lines.map(&:chomp)
        return false if lines.empty?

        # since the query uses regex, there may be multiple gem names that match
        # check for an exact match and a matching version
        lines.any? do |line|
          matches = line.match(/^(?<name>.*) \((?<versions>.*)\)/)
          next unless matches
          next unless matches[:name] == @component.name
          matches[:versions].split(', ').include?(@component.version)
        end
      end
    end

    private

    def ensure_rubygems_crendentials!
      gem_credentials_path = File.expand_path('~/.gem/credentials')
      raise "Your rubygems.org credentials aren't set. Run `gem push` to set them." unless File.exists?(gem_credentials_path)
    end

    def tmp_download_dir
      dir = "tmp/gems-#{@build_number}"
      FileUtils.mkdir_p(dir)
      dir
    end
  end
end
