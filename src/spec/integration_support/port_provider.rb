module IntegrationSupport
  class PortProvider
    BASE_PORT = 61000

    def initialize(test_env_number)
      @port_offset = test_env_number * 100
      @port_names = []
    end

    def get_port(name)
      @port_names << name unless @port_names.include?(name)
      BASE_PORT + @port_offset + @port_names.index(name)
    end
  end
end
