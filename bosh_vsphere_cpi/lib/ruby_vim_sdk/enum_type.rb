module VimSdk

  class EnumType < BaseType
    attr_accessor :values

    def initialize(name, wsdl_name, version, values)
      super(name, wsdl_name, version)
      @values = values
    end
  end

end