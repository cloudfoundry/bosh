module Bosh::Dev
  class GemArtifact
    def initialize(component, pipeline_prefix, build_number)
      @component = component
      @pipeline_prefix = pipeline_prefix
      @build_number = build_number
    end

    def promote
      ensure_rubygems_crendentials!

      dot_gem_path = "#{tmp_download_dir}/#{@component.dot_gem}"
      FileUtils.rm(dot_gem_path) if File.exists?(dot_gem_path)
      RakeFileUtils.sh("s3cmd --verbose get #{@pipeline_prefix}gems/gems/#{@component.dot_gem} #{tmp_download_dir}")
      Bundler.with_clean_env { RakeFileUtils.sh("gem push #{dot_gem_path}") }
      puts "Promoted: #{@component.dot_gem}"
    rescue
      warn "Failed to promote: #{@component.dot_gem}"
      raise
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
