module Bosh::Director

  # This is a work in progress.
  #
  # The App is the "top of the world"; it holds all the stateful components in the
  # system. There should be only one instance, available as a class instance to the
  # (hopefully few) components that require it.

  class App

    class << self
      # Some places (ie, resque jobs) need to reference the authoriative app instance
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

      # This is the legacy config system that we are trying to get rid of by
      # decomposing and moving all the dependent components into this App
      Bosh::Director::Config.configure(config.hash)

      @blobstores = Blobstores.new(config)
    end


  end
end
