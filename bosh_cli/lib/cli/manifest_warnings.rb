module Bosh::Cli
  class ManifestWarnings
    WARNING_MESSAGES = {
      'resource_pools.[].cloud_properties.spot_bid_price' => <<-EOM
AWS spot instance support is an experimental feature.
Please log an issue at https://github.com/cloudfoundry/bosh/issues if you run into any issues related to spot instances.
      EOM
    }

    def initialize(manifest)
      @manifest = manifest
    end

    def report
      WARNING_MESSAGES.each do |keypath, warning|
        say(warning.make_yellow) if keypath_exists?(manifest, keypath.split('.'))
      end
    end

    private

    attr_reader :manifest

    def keypath_exists?(config, keypath)
      case
        when keypath.empty?
          true

        when keypath.first == '[]'
          config.is_a?(Array) && config.any? { |element| keypath_exists?(element, keypath[1..-1]) }

        when config.respond_to?(:has_key?) && config.has_key?(keypath.first)
          keypath_exists?(config[keypath.first], keypath[1..-1])
      end
    end
  end
end
