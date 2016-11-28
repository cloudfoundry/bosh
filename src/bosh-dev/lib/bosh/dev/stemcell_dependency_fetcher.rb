require 'json'
require 'uri'

module Bosh::Dev
  class StemcellDependencyFetcher
    def initialize(downloader, logger)
      @downloader = downloader
      @logger = logger
    end

    def download_os_image(opts)
      bucket_name = opts[:bucket_name]
      key = opts[:key]
      output_path = opts[:output_path]

      os_image_versions_file = File.expand_path('../../../../../bosh-stemcell/os_image_versions.json', __FILE__)
      os_image_versions = JSON.load(File.open(os_image_versions_file))
      os_image_version = os_image_versions[key]
      if os_image_version.nil?
        raise "Unable to find OS image key '#{key}' in known versions: #{os_image_versions.to_json}"
      end

      os_image_uri = URI.join('https://s3.amazonaws.com/', "#{bucket_name}/", key)
      os_image_uri.query = URI.encode_www_form([['versionId', os_image_version]])

      @downloader.download(os_image_uri, output_path)
    end
  end
end
