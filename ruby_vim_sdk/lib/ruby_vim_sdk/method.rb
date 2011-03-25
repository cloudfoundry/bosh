module VimSdk

  class Method
    attr_accessor :name
    attr_accessor :wsdl_name
    attr_accessor :version
    attr_accessor :privilege
    attr_accessor :arguments
    attr_accessor :result_type
    attr_accessor :faults

    def initialize(name, wsdl_name, version, arguments, result, privilege, faults)
      @name = VmodlHelper.vmodl_property_to_ruby(name)
      @wsdl_name = wsdl_name
      @version = version
      @privilege = privilege
      @arguments = arguments.collect { |argument| Property.new(*argument) }
      @result_type = VmodlHelper.vmodl_type_to_ruby(result[1])
      @faults = faults.collect { |fault| VmodlHelper.vmodl_type_to_ruby(fault) } if faults
      @result_type_optional = false

      result[0].each do |key, value|
        case key
          when :optional
            @result_type_optional = value
          else
            raise "Unknown flag: #{key}"
        end
      end
    end

    def result_type_optional?
      @result_type_optional
    end
  end

end