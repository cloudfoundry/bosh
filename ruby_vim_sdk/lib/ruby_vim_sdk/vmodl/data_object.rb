module VimSdk
  module Vmodl
    class DataObject
      @type_info = DataType.new("vmodl.DataObject", "DataObject", nil, VimSdk::BASE_VERSION, [])
      @resolved_properties = nil

      class << self
        attr_reader :type_info

        [:name, :wsdl_name, :version, :properties].each do |name|
          define_method(name) { @type_info.send(name) }
        end

        def property_list(include_base_class_props = true)
          return properties unless include_base_class_props
          return @resolved_properties unless @resolved_properties.nil?

          result = []
          property_names = Set.new

          current_class = self
          while current_class != DataObject
            properties = current_class.type_info.properties
            if properties
              properties.reverse.each do |property|
                unless property_names.include?(property.name)
                  result.unshift(property)
                  property_names << property.name
                end
              end
            end
            current_class = current_class.superclass
          end

          @resolved_properties = result
        end

        def build_property_indices
          @property_by_name = {}
          @property_by_wsdl_name = {}
          property_list.each do |property|
            @property_by_name[property.name] = property
            @property_by_wsdl_name[property.wsdl_name] = property
          end
        end

        def property(options = {})
          if options[:name]
            @property_by_name[options[:name]]
          elsif options[:wsdl_name]
            @property_by_wsdl_name[options[:wsdl_name]]
          end
        end

        def finalize
          build_property_indices
          @type_info.properties.each do |property|
            property.type = VmomiSupport.loaded_type(property.type) if property.type.kind_of?(String)
            self.instance_eval do
              attr_accessor(property.name)
            end
          end
        end

      end

      def initialize(properties = {})

        self.class.property_list.each do |property|
          subclasses = Set.new(property.type.ancestors)
          if subclasses.include?(Array)
            default_value = property.type.new
          elsif property.optional?
            default_value = nil
          elsif property.type == SoapBoolean
            default_value = false
          elsif subclasses.include?(SoapEnum)
            default_value = nil
          elsif subclasses.include?(String)
            default_value = ""
          elsif [SoapByte, SoapShort, SoapLong, SoapInteger].include?(property.type)
            default_value = 0
          elsif [SoapFloat, SoapDouble].include?(property.type)
            default_value = 0.0
          else
            default_value = nil
          end
          instance_variable_set("@#{property.name}", default_value)
        end

        properties.each do |key, value|
          if self.class.property(:name => key.to_s)
            instance_variable_set("@#{key}", value)
          else
            raise "Invalid property: #{key}"
          end
        end
      end

    end
  end
end