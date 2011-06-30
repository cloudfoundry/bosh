
module Bosh::Agent
  class UnknownPlatform < StandardError; end

  class Platform

    def initialize(platform_name)
      # TODO: add to loadpath?
      platform = File.join(File.dirname(__FILE__), 'platform', "#{platform_name}.rb")

      if File.exist?(platform)
        load platform
      else
        raise UnknownPlatform
      end
    end

    def platform
      Ubuntu.new
    end

  end
end
