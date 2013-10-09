module Bosh::Dev
  class GemArtifact
    def initialize(component, pipeline_prefix, build_number)
      @component = component
      @pipeline_prefix = pipeline_prefix
      @build_number = build_number
    end

    def promote
      ensure_rubygems_crendentials!

      RakeFileUtils.sh("s3cmd --verbose get #{@pipeline_prefix}/gems/gems/#{@component.dot_gem} #{tmp_download_dir}")
      RakeFileUtils.sh("gem push #{tmp_download_dir}/#{@component.dot_gem}")
    end

    private
    def ensure_rubygems_crendentials!
      raise "Your rubygems.org credentials aren't set. Run `gem push` to set them." unless File.exists?('~/.gem/credentials')
    end

    def tmp_download_dir
      dir = "tmp/gems-#{@build_number}"
      FileUtils.mkdir_p(dir)
      dir
    end
  end
end
