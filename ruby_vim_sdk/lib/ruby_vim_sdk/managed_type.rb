module VimSdk

  class ManagedType < DataType
    attr_accessor :managed_methods

    def initialize(name, wsdl_name, parent, version, properties, methods)
      super(name, wsdl_name, parent, version, properties)
      @managed_methods = methods ? methods.collect { |method| Method.new(*method) } : []
    end
  end

end