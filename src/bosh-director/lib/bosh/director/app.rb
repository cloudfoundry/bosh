module Bosh::Director

  # This is a work in progress.
  #
  # The App is the "top of the world"; it holds all the stateful components in the
  # system. There should be only one instance, available as a class instance to the
  # (hopefully few) components that require it.

  class App
    class << self
      # Some places need to reference the authoritative app instance
      # from class methods.
      def instance
        @@instance
      end
    end

    attr_reader :blobstores

    def initialize(config)
      # You should only create one of these at a time, but when you create one
      # it becomes the authoritative official version across the whole app.
      @@instance = self
      config.configure_evil_config_singleton!

      @blobstores = Blobstores.new(config)
    end
  end
end
