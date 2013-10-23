module VimSdk

  class DataType < BaseType
    attr_accessor :parent
    attr_accessor :properties

    def initialize(name, wsdl_name, parent, version, properties)
      super(name, wsdl_name, version)
      @parent = VmodlHelper.vmodl_type_to_ruby(parent) if parent
      @properties = properties ? properties.collect { |property| Property.new(*property) } : []
    end
  end

end