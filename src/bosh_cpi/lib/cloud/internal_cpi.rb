module Bosh::Clouds
  class InternalCpi
    def initialize(cloud)
      @cloud = cloud
    end

    private

    def method_missing(method_sym, *arguments, &block)
      invoke_cpi_method(method_sym, arguments)
    end

    def respond_to?(method_sym)
      cloud.respond_to?(method_sym)
    end

    def cloud
      @cloud
    end

    def invoke_cpi_method(method_sym, arguments)
      cloud.send(method_sym, *JSON.parse(JSON.dump(arguments)))
    end
  end
end
