module VimSdk
  module Soap

    class StubAdapter
      PC = Vmodl::Query::PropertyCollector

      attr_reader :version

      def initialize(uri, version, http_client)
        @uri = URI.parse(uri)
        @version = version
        @version_id = compute_version_id(version)
        @http_client = http_client
        @cookie = ""
        @property_collector = nil
      end

      def cookie
        @http_client.cookie_manager.find(@uri)
      end

      def invoke_method(managed_object, method_info, arguments, outer_stub = nil)
        outer_stub = self if outer_stub.nil?
        headers = {"SOAPAction"      => @version_id,
                   "Accept-Encoding" => "gzip, deflate",
                   "Content-Type"    => "text/xml; charset=#{XML_ENCODING}"}

        request = serialize_request(managed_object, method_info, arguments)
        response = @http_client.post(@uri, request, headers)

        status = response.code
        if status == 200 || status == 500
          object = SoapResponseDeserializer.new(outer_stub).deserialize(response.content, method_info.result_type)
          if outer_stub != self
            result = [status, object]
          elsif status == 200
            result = object
          elsif object.kind_of?(Vmodl::MethodFault)
            raise SoapException.new(object.msg, object)
          else
            raise SoapException.new("Unknown SOAP fault", object)
          end
        else
          raise Net::HTTPError.new("#{status}", nil)
        end
        result
      end

      def invoke_property(managed_object, property_info)
        filter_spec = PC::FilterSpec.new(
          :object_set => [PC::ObjectSpec.new(:obj => managed_object, :skip => false)],
          :prop_set => [PC::PropertySpec.new(:all => false, :type => managed_object.class,
                                             :path_set => [property_info.wsdl_name])])

        if @property_collector.nil?
          service_instance    = Vim::ServiceInstance.new("ServiceInstance", self)
          @property_collector = service_instance.retrieve_content.property_collector
        end

        @property_collector.retrieve_contents([filter_spec]).first.prop_set.first.val
      end

      def compute_version_id(version)
        version_ns = VmomiSupport.version_namespace(version)
        if version_ns.index("/")
          "\"urn:#{version_ns}\""
        else
          ""
        end
      end

      def serialize_request(managed_object, info, arguments)
        if !VmomiSupport.is_child_version(@version, info.version)
          fault = Vmodl::Fault::MethodNotFound.new
          fault.receiver = managed_object
          fault.method = info.name
          raise SoapException(fault)
        end

        namespace_map = SOAP_NAMESPACE_MAP.dup
        default_namespace = VmomiSupport.wsdl_namespace(@version)
        namespace_map[default_namespace] = ""

        result = [XML_HEADER, "\n", SOAP_ENVELOPE_START]
        result << SOAP_BODY_START
        result << "<#{info.wsdl_name} xmlns=\"#{default_namespace}\">"
        property = Property.new("_this", "Vmodl.ManagedObject", @version)
        property.type = Vmodl::ManagedObject
        result << serialize(managed_object, property, @version, namespace_map)

        info.arguments.zip(arguments).each do |parameter, argument|
          result << serialize(argument, parameter, @version, namespace_map)
        end

        result << "</#{info.wsdl_name}>"
        result << SOAP_BODY_END
        result << SOAP_ENVELOPE_END

        result.join("")
      end

      def serialize(object, info, version, namespace_map)
        if version.nil?
          if object.kind_of?(Array)
            item_type = object.class.type_info
            version = item_type.version
          else
            if object.nil?
              return ""
            end
            version = object.class.type_info.version
          end
        end

        writer = StringIO.new
        SoapSerializer.new(writer, version, namespace_map).serialize(object, info)
        writer.string
      end

    end

  end
end
