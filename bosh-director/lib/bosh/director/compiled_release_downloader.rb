require 'fileutils'
require 'tmpdir'
require 'bosh/director'

module Bosh::Director
  class CompiledReleaseDownloader
    def initialize(compiled_packages_group, templates, blobstore_client)
      @compiled_packages_group = compiled_packages_group
      @templates = templates
      @blobstore_client = blobstore_client
    end

    def download
      @download_dir = Dir.mktmpdir

      path = File.join(@download_dir, 'compiled_packages')
      FileUtils.mkpath(path)

      @compiled_packages_group.compiled_packages.each do |compiled_package|
        blobstore_id = compiled_package.blobstore_id
        File.open(File.join(path, "#{compiled_package.package.name}.tgz"), 'w') do |f|
          @blobstore_client.get(blobstore_id, f, sha1: compiled_package.sha1)
        end
      end

      path = File.join(@download_dir, 'jobs')
      FileUtils.mkpath(path)

      @templates.each do |template|
        blobstore_id = template.blobstore_id
        File.open(File.join(path, "#{template.name}.tgz"), 'w') do |f|
          @blobstore_client.get(blobstore_id, f, sha1: template.sha1)
        end
      end

      @download_dir
    end

    def cleanup
      FileUtils.rm_rf(@download_dir)
    end
  end
end
