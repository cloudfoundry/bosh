require 'blobstore_client'
require 'yaml'
require "yajl"

module VCAP
  module Micro

    # Cache blobstore playloads on local file system
    class Cache
      attr_reader :state

      def initialize(state_file, cache_dir, settings_file)
        @state_file = state_file
        @cache_dir = cache_dir
        @settings_file = settings_file
      end

      def setup
        load_settings
        load_state

        bs_opts = @settings['blobstore']['properties']
        @blobstore_client = Bosh::Blobstore::SimpleBlobstoreClient.new(bs_opts)
      end

      def load_settings
        settings_json = File.read(@settings_file)
        @settings = Yajl::Parser.new.parse(settings_json)
      end

      def load_state
        @state = YAML.load_file(@state_file)
      end

      def load_blobstore_ids
        blobstore_ids = []
        blobstore_ids << @state['job']['blobstore_id']

        @state['packages'].each do |pkg_name, pkg_data|
          blobstore_ids << pkg_data['blobstore_id']
        end
        blobstore_ids
      end

      def download
        FileUtils.mkdir_p(@cache_dir)

        load_blobstore_ids.each do |blobstore_id|
          download_blob(blobstore_id)
        end
      end

      def download_blob(blobstore_id)
        cache_file = File.join(@cache_dir, blobstore_id)

        File.open(cache_file, 'w') do |fh|
          @blobstore_client.get(blobstore_id, fh)
        end
      end

    end
  end
end

if $0 == __FILE__
  cache = VCAP::Micro::Cache.new('/var/vcap/bosh/state.yml', '/var/vcap/data/cache', '/var/vcap/bosh/settings.json')
  cache.setup
  cache.download
end
