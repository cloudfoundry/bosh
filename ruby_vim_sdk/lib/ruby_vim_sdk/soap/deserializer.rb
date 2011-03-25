module VimSdk
  module Soap

    class DelegatedDocument < DelegateClass(Nokogiri::XML::SAX::Document)

      def initialize(delegate = nil)
        super(delegate)
      end

    end

    class NamespacedDocument < Nokogiri::XML::SAX::Document
      def initialize(namespace_map = nil)
        @namespace_map = namespace_map || {}
        @prefix_stack = []
      end

      def start_namespaced_element(name, attrs)
      end

      def end_namespaced_element(name)
      end

      def namespace_and_wsdl_name(tag)
        index = tag.index(":")
        if index
          prefix, name = tag[0..index - 1], tag[index + 1..-1]
        else
          prefix, name = nil, tag
        end
        namespace = @namespace_map[prefix].last
        [namespace, name]
      end

      def start_element_namespace(name, attrs = [], prefix = nil, uri = nil, ns = [])
        prefixes = []
        ns.each do |namespace_prefix, namespace|
          (@namespace_map[namespace_prefix] ||= []) << namespace
          prefixes << namespace_prefix
        end
        @prefix_stack << prefixes
        namespaced_attrs = {}
        attrs.each do |attr|
          attr_uri = attr.uri || uri
          namespaced_attrs[[attr_uri, attr.localname]] = attr.value
        end

        start_namespaced_element([uri, name], namespaced_attrs)
      end

      def end_element_namespace(name, prefix = nil, uri = nil)
        end_namespaced_element([uri, name])

        unless @prefix_stack.empty?
          prefixes = @prefix_stack.pop
          prefixes.each { |namespace_prefix| @namespace_map[namespace_prefix].pop }
        end
      end

    end

    class SoapDeserializer < NamespacedDocument

      attr_accessor :result

      def initialize(stub = nil, version = nil)
        super(nil)
        @stub = stub
        if version
          @version = version
        elsif @stub
          @version = @stub.version
        else
          @version = nil
        end
        @result = nil
      end

      def deserialize(delegated_document, result_type = Object, is_fault = false, namespace_map = nil)
        @is_fault = is_fault

        @delegated_document = delegated_document
        @original_document = @delegated_document.__getobj__
        @delegated_document.__setobj__(self)

        @result_type = result_type
        @stack = []
        @data = ""

        if @result_type.ancestors.include?(Array)
          @result = []
        else
          @result = nil
        end

        @namespace_map = namespace_map || {}
      end

      def lookup_wsdl_type(namespace, name, allow_managed_object_reference = false)
        begin
          return VmomiSupport.loaded_wsdl_type(namespace, name)
        rescue
          if allow_managed_object_reference
            if name =~ /ManagedObjectReference/ && namespace == XMLNS_VMODL_BASE
              return VmomiSupport.loaded_wsdl_type(namespace, name[0..-("Reference".length + 1)])
            end
          end

          if name =~ /ManagedObjectReference/ && allow_managed_object_reference
            return VmomiSupport.loaded_wsdl_type(XMLNS_VMODL_BASE, name[0..-("Reference".length + 1)])
          end
          return VmomiSupport.guess_wsdl_type(name)
        end
      end

      def start_namespaced_element(name, attrs = {})
        @data = ""
        deserialize_as_localized_method_fault = true
        if @stack.empty?
          if @is_fault
            object_type = lookup_wsdl_type(name[0], name[1][0..-("Fault".length + 1)])
            deserialize_as_localized_method_fault = false
          else
            object_type = @result_type
          end
        else
          parent_object = @stack.last
          if parent_object.kind_of?(Array)
            object_type = parent_object.class.item
          elsif parent_object.kind_of?(Vmodl::DataObject)
            object_type = parent_object.class.property(:wsdl_name => name[1]).type
            if name[1] == "fault" and parent_object.kind_of?(Vmodl::LocalizedMethodFault)
              deserialize_as_localized_method_fault = false
            end
          else
            raise "Invalid type for tag #{name.pretty_inspect}"
          end
        end

        xsi_type = attrs[[XMLNS_XSI, "type"]]
        if xsi_type
          unless DYNAMIC_TYPES.include?(object_type)
            name = namespace_and_wsdl_name(xsi_type)
            dynamic_type = lookup_wsdl_type(name[0], name[1], true)
            object_type = dynamic_type unless dynamic_type.kind_of?(Array) || object_type.kind_of?(Array)
          end
        else
          object_type = object_type.item if object_type.ancestors.include?(Array)
        end

        object_type = VmomiSupport.compatible_type(object_type, @version) if @version
        ancestor_set = Set.new(object_type.ancestors)
        if ancestor_set.include?(Vmodl::ManagedObject)
          type_attr = attrs[[name[0], "type"]]
          type_name = namespace_and_wsdl_name(type_attr)
          @stack << VmomiSupport.guess_wsdl_type(type_name[1])
        elsif ancestor_set.include?(Vmodl::DataObject) || ancestor_set.include?(Array)
          if deserialize_as_localized_method_fault and object_type.ancestors.include?(Vmodl::MethodFault)
             object_type = Vmodl::LocalizedMethodFault
          end
          @stack << object_type.new
        else
          @stack << object_type
        end
      end

      def end_namespaced_element(name)
        if @stack.empty?
          @delegated_document.__setobj__(@original_document)
          @original_document.end_namespaced_element(name)
          return
        end

        object = @stack.pop

        if object.kind_of?(Class) || object == Vmodl::TypeName
          if object == Vmodl::TypeName
            if @data.empty?
              object = nil
            else
              object_name = namespace_and_wsdl_name(@data)
              object = VmomiSupport.guess_wsdl_type(object_name[1])
            end
          elsif object == Vmodl::MethodName
            object_name = namespace_and_wsdl_name(@data)
            object = VmomiSupport.guess_wsdl_type(object_name[1])
          elsif object == SoapBoolean
            if @data == "0" || @data.downcase == "false"
              object = false
            elsif @data == "1" || @data.downcase == "true"
              object = true
            else
              raise "Invalid boolean value: #{@data}"
            end
          elsif object == SoapBinary
            object = Base64.decode64(@data)
          elsif object == String
            object = @data
          elsif object == Time
            object = Time.iso8601(@data)
          else
            ancestor_set = Set.new(object.ancestors)
            if ancestor_set.include?(Vmodl::ManagedObject)
              object = object.new(@data, @stub)
            elsif object.ancestors.include?(SoapEnum)
              object = object.const_get(VmodlHelper.underscore(@data).upcase)
            elsif object == SoapFloat || object == SoapDouble
              object = Float(@data)
            elsif object == SoapInteger || object == SoapByte || object == SoapShort || object == SoapLong
              object = Integer(@data)
            else
              object = object.new(@data)
            end
          end
        elsif object.kind_of?(Vmodl::LocalizedMethodFault)
          object.fault.msg = object.localized_message
          object = object.fault
        end

        if !@stack.empty?
          parent_object = @stack.last
          if parent_object.kind_of?(Array)
            parent_object << object
          elsif parent_object.kind_of?(Vmodl::DataObject)
            property_info = parent_object.class.property(:wsdl_name => name[1])
            raise "Can't find #{name[1]} for #{parent_object.class.name}" if property_info.nil?
            if !object.kind_of?(Array) && property_info.type.ancestors.include?(Array)
              parent_object.send(property_info.name) << object
            else
              parent_object.send("#{property_info.name}=".to_sym, object)
            end
          else
            parent_object.send("#{name[1]}=", object)
          end
        else
          if !object.kind_of?(Array) && @result_type.ancestors.include?(Array)
            @result << object
          else
            @result = object
            @delegated_document.__setobj__(@original_document)
          end
        end
      end

      def characters(string)
        @data += string
      end
    end

    class SoapResponseDeserializer < NamespacedDocument

      def initialize(stub)
        super
        @stub = stub
        @deserializer = SoapDeserializer.new(stub)
      end

      def deserialize(contents, result_type, namespace_map = nil)
        @result_type = result_type
        @stack = []
        @message = ""
        @data = ""
        @deserializer.result = nil
        @is_fault = false
        @delegated_document = DelegatedDocument.new(self)
        @parser = Nokogiri::XML::SAX::Parser.new(@delegated_document)
        @namespace_map = namespace_map || {}
        @parser.parse(contents)
        result = @deserializer.result
        if @is_fault
          result = Vmodl::RuntimeFault.new if result.nil?
          result.msg = @message
        end
        result
      end

      def start_namespaced_element(name, attrs = {})
        @data = ""
        if name == [XMLNS_SOAPENV, "Fault"]
          @is_fault = true
        elsif @is_fault && name[1] == "detail"
          @deserializer.deserialize(@delegated_document, Class, true, @namespace_map)
        elsif name[1] =~ /Response$/
          @deserializer.deserialize(@delegated_document, @result_type, false, @namespace_map)
        end
      end

      def end_namespaced_element(name)
        if @is_fault && name[1] == "faultstring"
          @message = @data
        end
      end

      def characters(string)
        @data += string
      end

    end

  end
end
