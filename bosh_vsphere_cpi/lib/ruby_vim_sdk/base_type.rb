module VimSdk

  class BaseType
    attr_accessor :name
    attr_accessor :wsdl_name
    attr_accessor :version

    def initialize(name, wsdl_name, version)
      @name = VmodlHelper.vmodl_type_to_ruby(name)
      @wsdl_name = wsdl_name
      @version = version
    end
  end

end