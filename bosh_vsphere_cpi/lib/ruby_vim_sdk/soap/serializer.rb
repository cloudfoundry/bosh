module VimSdk
  module Soap

    class SoapSerializer

      def initialize(writer, version, namespace_map)
        @writer = writer
        @version = version
        @namespace_map = namespace_map

        @namespace_map.each do |namespace, prefix|
          if prefix == ""
            @default_namespace = namespace
            break
          end
        end
        @default_namespace = "" if @default_namespace.nil?

        @outermost_attributes = ""

        [["xsi", XMLNS_XSI, :@xsi_prefix],
         ["xsd", XMLNS_XSD, :@xsd_prefix]].each do |namespace_prefix, namespace, variable_name|
          prefix = @namespace_map[namespace]
          unless prefix
            prefix = namespace_prefix
            @outermost_attributes += " xmlns:#{prefix}=\"#{namespace}\""
            @namespace_map = @namespace_map.dup
            @namespace_map[namespace] = prefix
          end
          instance_variable_set(variable_name, "#{prefix}:")
        end
      end

      def serialize(value, info, default_namespace = @default_namespace)
        return unless VmomiSupport.is_child_version(@version, info.version)

        if value.nil?
          return if info.optional?
          raise "Field #{info.name} is not optional"
        elsif value.kind_of?(Array) && value.empty?
          if info.type == Object
            raise "Cannot assign empty 'untyped' array to an Any" unless value.class.ancestors.include?(TypedArray)
          elsif info.optional?
            return
          else
            raise "Field #{info.name} is not optional"
          end
        end

        if @outermost_attributes
          attribute = @outermost_attributes
          @outermost_attributes = nil
        else
          attribute = ""
        end

        current_default_namespace = default_namespace
        current_tag_namespace = VmomiSupport.wsdl_namespace(info.version)
        if current_tag_namespace != default_namespace
          attribute += " xmlns=\"#{current_tag_namespace}\""
          current_default_namespace = current_tag_namespace
        end

        if value.kind_of?(Vmodl::ManagedObject)
          if info.type == Object
            namespace_attribute, qualified_name = qualified_name(Vmodl::ManagedObject, current_default_namespace)
            attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
          end
          _, name = VmomiSupport.qualified_wsdl_name(value.class)
          attribute += " type=\"#{name}\""
          @writer << "<#{info.wsdl_name}#{attribute}>#{value.__mo_id__.to_xs}</#{info.wsdl_name}>"
        elsif value.kind_of?(Vmodl::DataObject)
          if value.kind_of?(Vmodl::MethodFault)
            localized_method_fault = Vmodl::LocalizedMethodFault.new
            localized_method_fault.fault = value
            localized_method_fault.localized_message = value.msg

            unless info.type == Object
              info = info.dup
              info.type = Vmodl::LocalizedMethodFault
            end

            serialize_data_object(localized_method_fault, info, attribute, current_default_namespace)
          else
            serialize_data_object(value, info, attribute, current_default_namespace)
          end
        elsif value.kind_of?(Array)
          if info.type == Object
            if value.class.respond_to?(:item)
              item_type = value.class.item
            else
              item_type = value.first.class
            end

            if DYNAMIC_TYPES.include?(item_type)
              tag = "string"
              type = String::TypedArray
            elsif item_type.ancestors.include?(Vmodl::ManagedObject)
              tag = "ManagedObjectReference"
              type = Vmodl::ManagedObject::TypedArray
            else
              tag = VmomiSupport.wsdl_name(item_type)
              type = item_type::TypedArray
            end

            namespace_attribute, qualified_name = qualified_name(type, current_default_namespace)
            attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
            @writer << "<#{info.wsdl_name}#{attribute}>"

            item_info = info.dup
            item_info.wsdl_name = tag
            item_info.type = value.class

            value.each do |child|
              serialize(child, item_info, current_default_namespace)
            end

            @writer << "</#{info.wsdl_name}>"
          else
            item_info = info.dup
            item_info.type = info.type.item
            value.each do |v|
              serialize(v, item_info, default_namespace)
            end
          end
        elsif value.kind_of?(Class)
          if info.type == Object
            attribute += " #{@xsi_prefix}type=\"#{@xsd_prefix}string\""
          end
          @writer << "<#{info.wsdl_name}#{attribute}>#{VmomiSupport.wsdl_name(value)}</#{info.wsdl_name}>"
        elsif value.kind_of?(Vmodl::MethodName)
          if info.type == Object
            attribute += " #{@xsi_prefix}type=\"#{@xsd_prefix}string\""
          end
          @writer << "<#{info.wsdl_name}#{attribute}>#{value}</#{info.wsdl_name}>"
        elsif value.kind_of?(Time)
          if info.type == Object
            namespace_attribute, qualified_name = qualified_name(value.class, current_default_namespace)
            attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
          end
          @writer << "<#{info.wsdl_name}#{attribute}>#{value.utc.iso8601}</#{info.wsdl_name}>"
        elsif value.kind_of?(SoapBinary) || info.type == SoapBinary
          if info.type == Object
            namespace_attribute, qualified_name = qualified_name(value.class, current_default_namespace)
            attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
          end
          @writer << "<#{info.wsdl_name}#{attribute}>#{Base64.encode64(value)}</#{info.wsdl_name}>"
        elsif value.kind_of?(TrueClass) || value.kind_of?(FalseClass) || value.kind_of?(SoapBoolean)
          if info.type == Object
            namespace_attribute, qualified_name = qualified_name(value.class, current_default_namespace)
            attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
          end
          @writer << "<#{info.wsdl_name}#{attribute}>#{value ? "true" : "false"}</#{info.wsdl_name}>"
        else
          if info.type == Object
            if value.kind_of?(Vmodl::PropertyPath)
              attribute += " #{@xsi_prefix}type=\"#{@xsd_prefix}string\""
            else
              namespace_attribute, qualified_name = qualified_name(value.class, current_default_namespace)
              attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
            end
          end
          value = value.to_s unless value.kind_of?(String)
          @writer << "<#{info.wsdl_name}#{attribute}>#{value.to_xs}</#{info.wsdl_name}>"
        end
      end

      def serialize_data_object(value, info, attribute, current_default_namespace)
        dynamic_type = VmomiSupport.compatible_type(value.class, @version)
        if dynamic_type != info.type
          namespace_attribute, qualified_name = qualified_name(dynamic_type, current_default_namespace)
          attribute += "#{namespace_attribute} #{@xsi_prefix}type=\"#{qualified_name}\""
        end
        @writer << "<#{info.wsdl_name}#{attribute}>"
        if dynamic_type.kind_of?(Vmodl::LocalizedMethodFault)
          info.type.property_list.each do |property|
            property_value = value.send(property.name)
            if property.name == "fault"
              property_value = property_value.dup
              property_value.msg = nil
              serialize_data_object(property_value, property, "", current_default_namespace)
            else
              serialize(property_value, property, current_default_namespace)
            end
          end
        else
          value.class.property_list.each do |property|
            serialize(value.__send__(property.name), property, current_default_namespace)
          end
        end
        @writer << "</#{info.wsdl_name}>"
      end

      def serialize_fault_detail(value, type_info)
        serialize_data_object(value, type_info, "", @default_namespace)
      end

      def namespace_prefix(namespace)
        if namespace == @default_namespace
          ""
        else
          prefix = @namespace_map[namespace]
          prefix ? "#{prefix}:" : ""
        end
      end

      def qualified_name(type, default_namespace)
        attribute = ""
        namespace, name = VmomiSupport.qualified_wsdl_name(type)
        if namespace == default_namespace
          prefix = ""
        else
          prefix = @namespace_map[namespace]
          unless prefix
            prefix = namespace.split(":", 2).last
            attribute = " xmlns:#{prefix}=\"#{namespace}\""
          end
        end
        [attribute, prefix.empty? ? name : "#{prefix}:#{name}"]
      end

    end

  end
end
