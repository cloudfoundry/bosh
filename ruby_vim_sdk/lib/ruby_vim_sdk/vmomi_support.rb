module VimSdk

  module VmomiSupport

    @logger = Logger.new(STDOUT)

    @type_info = {}
    @wsdl_type_info = {}

    @versions = {}
    @version_ids = {}
    @version_parents = {}
    @version_namespaces = {}
    @service_version_namespaces = {BASE_VERSION => XMLNS_VMODL_BASE.split(":").last}

    @wsdl_types = {
      [XMLNS_XSD, "void"] => NilClass,
      [XMLNS_XSD, "anyType"] => Object,
      [XMLNS_XSD, "boolean"] => SoapBoolean,
      [XMLNS_XSD, "byte"] => SoapByte,
      [XMLNS_XSD, "short"] => SoapShort,
      [XMLNS_XSD, "int"] => SoapInteger,
      [XMLNS_XSD, "long"] => SoapLong,
      [XMLNS_XSD, "float"] => SoapFloat,
      [XMLNS_XSD, "double"] => SoapDouble,
      [XMLNS_XSD, "string"] => String,
      [XMLNS_XSD, "anyURI"] => SoapURI,
      [XMLNS_XSD, "base64Binary"] => SoapBinary,
      [XMLNS_XSD, "dateTime"] => Time,
      [XMLNS_VMODL_BASE, "DataObject"] => Vmodl::DataObject,
      [XMLNS_VMODL_BASE, "ManagedObject"] => Vmodl::ManagedObject,
      [XMLNS_VMODL_BASE, "MethodName"] => Vmodl::MethodName,
      [XMLNS_VMODL_BASE, "PropertyPath"] => Vmodl::PropertyPath,
      [XMLNS_VMODL_BASE, "TypeName"] => Vmodl::TypeName
    }
    @wsdl_names = @wsdl_types.invert
    @wsdl_type_namespaces = Set.new

    @wsdl_types.dup.each do |namespaced_name, type|
      namespace, name = namespaced_name
      vmodl_name = namespace == XMLNS_VMODL_BASE ? "Vmodl.#{name}" : name
      if type != NilClass
        @wsdl_type_namespaces << namespace
        array_type = Class.new(TypedArray) { @item = type }
        type.const_set(:TypedArray, array_type)
        array_name = "ArrayOf#{VmodlHelper.camelize(name)}"
        array_namespace = XMLNS_VMODL_BASE
        @wsdl_types[[array_namespace, array_name]] = array_type
        @wsdl_names[array_type] = [array_namespace, array_name]
      end
    end

    @wsdl_names[Class] = [XMLNS_XSD, "TypeName"]
    @wsdl_names[FalseClass] = [XMLNS_XSD, "boolean"]
    @wsdl_names[TrueClass] = [XMLNS_XSD, "boolean"]
    @wsdl_names[Fixnum] = [XMLNS_XSD, "int"]
    @wsdl_names[Float] = [XMLNS_XSD, "float"]

    @types = {
      "Void"   => @wsdl_types[[XMLNS_XSD, "void"]],
      "AnyType"=> @wsdl_types[[XMLNS_XSD, "anyType"]],
      "String" => @wsdl_types[[XMLNS_XSD, "string"]],
      "Bool"   => @wsdl_types[[XMLNS_XSD, "boolean"]],
      "Boolean"=> @wsdl_types[[XMLNS_XSD, "boolean"]],
      "Byte"   => @wsdl_types[[XMLNS_XSD, "byte"]],
      "Short"  => @wsdl_types[[XMLNS_XSD, "short"]],
      "Int"    => @wsdl_types[[XMLNS_XSD, "int"]],
      "Long"   => @wsdl_types[[XMLNS_XSD, "long"]],
      "Float"  => @wsdl_types[[XMLNS_XSD, "float"]],
      "Double" => @wsdl_types[[XMLNS_XSD, "double"]],
      "Vmodl.URI"        => @wsdl_types[[XMLNS_XSD, "anyURI"]],
      "Vmodl.Binary"     => @wsdl_types[[XMLNS_XSD, "base64Binary"]],
      "Vmodl.DateTime"   => @wsdl_types[[XMLNS_XSD, "dateTime"]],
      "Vmodl.TypeName"   => @wsdl_types[[XMLNS_VMODL_BASE, "TypeName"]],
      "Vmodl.MethodName" => @wsdl_types[[XMLNS_VMODL_BASE, "MethodName"]],
      "Vmodl.DataObject" => @wsdl_types[[XMLNS_VMODL_BASE, "DataObject"]],
      "Vmodl.ManagedObject" => @wsdl_types[[XMLNS_VMODL_BASE, "ManagedObject"]],
      "Vmodl.PropertyPath"  => @wsdl_types[[XMLNS_VMODL_BASE, "PropertyPath"]]
    }

    @types.dup.each do |name, type|
      if type != NilClass
        array_type = type.const_get(:TypedArray)
        array_name = "#{name}[]"
        @types[array_name] = array_type
      end
    end

    class << self

      attr_reader :logger

      def add_version(version, ns, version_id, is_legacy, service_ns)
        unless @version_parents.has_key?(version)
          @version_namespaces[version] = ns
          @versions["#{ns}/#{version_id}"] = version unless version_id.empty?
          @versions[ns] = version if is_legacy || ns.empty?
          @version_ids[version] = version_id
          service_ns = ns if service_ns.nil?
          @service_version_namespaces[version] = service_ns
          @version_parents[version] = {}
        end
      end

      def add_version_parent(version, parent)
        @version_parents[version][parent] = true
      end

      def create_data_type(*args)
        add_type(DataType.new(*args))
      end

      def create_enum_type(*args)
        add_type(EnumType.new(*args))
      end

      def create_managed_type(*args)
        add_type(ManagedType.new(*args))
      end

      def version_namespace(version)
        namespace = @version_namespaces[version]
        version_id = @version_ids[version]

        if version_id
          "#{namespace}/#{version_id}"
        else
          namespace
        end
      end

      def add_type(type)
        @type_info[type.name] = type
        namespace = wsdl_namespace(type.version)
        @wsdl_type_namespaces << namespace

        if @wsdl_type_info.has_key?([namespace, type.wsdl_name])
          raise "Duplicate wsdl type #{type.wsdl_name} (already in typemap)" if @wsdl_type_info[namespace, type.wsdl_name] != type
        else
          @wsdl_type_info[[namespace, type.wsdl_name]] = type
        end
      end

      def wsdl_namespace(version)
        "urn:#{@service_version_namespaces[version]}"
      end

      def is_child_version(a, b)
        a == b || (@version_parents[a] && @version_parents[a][b])
      end

      def compatible_type(type, version)
        if type.respond_to?(:version)
          type = type.superclass until is_child_version(version, type.version)
        end
        type
      end

      def guess_wsdl_type(name)
        @wsdl_type_namespaces.each do |namespace|
          type = @wsdl_types[[namespace, name]]
          return type if type
        end
        raise "Couldn't guess type for #{name}"
      end

      def load_types
        @type_info.each_value do |type|
          load_type(type) unless @types.has_key?(type.name)
        end

        @types.each_value do |clazz|
          type_info = clazz.instance_eval { @type_info }
          if type_info
            if type_info.kind_of?(DataType)
              clazz.finalize
            elsif type_info.class == EnumType
              type_info.values.each do |value|
                clazz.const_set(VmodlHelper.underscore(value).upcase, value)
              end
            end
          end
        end
      end

      def load_type(type)
        if type.respond_to?(:parent)
          parent = type.parent
        else
          parent = nil
        end

        unless parent.nil? || @types.has_key?(type.parent)
          load_type(@type_info[type.parent])
        end

        names = type.name.split(".")

        current_name = ""
        current_module = VimSdk

        names[0..-2].each do |name|
          if current_name.empty?
            current_name = name
          else
            current_name = "#{current_name}.#{name}"
          end

          module_name = name.to_sym
          unless current_module.const_defined?(module_name)
            if @type_info.has_key?(current_name)
              load_type(@type_info[current_name])
            else
              current_module.const_set(module_name, Module.new)
            end
          end
          current_module = current_module.const_get(module_name)
        end

        if type.kind_of?(EnumType)
          super_class = SoapEnum
        else
          super_class = @types[type.parent]
        end

        clazz = Class.new(super_class) do
          @type_info = type
        end
        current_module.const_set(names.last, clazz)

        array_clazz = Class.new(TypedArray) do
          @item = clazz
        end
        clazz.const_set(:TypedArray, array_clazz)

        @types[type.name] = clazz
        @types["#{type.name}[]"] = array_clazz
        @wsdl_types[[wsdl_namespace(type.version), type.wsdl_name]] = clazz
        @wsdl_types[[wsdl_namespace(type.version), "ArrayOf#{type.wsdl_name}"]] = array_clazz
      end

      def loaded_type(type_name)
        raise "Can't find #{type_name}" unless @types[type_name]
        @types[type_name]
      end

      def loaded_wsdl_type(namespace, name)
        raise "Can't find #{namespace}/#{name}" unless @wsdl_types[[namespace, name]]
        @wsdl_types[[namespace, name]]
      end

      def qualified_wsdl_name(type)
        result = @wsdl_names[type]
        if result
          result
        else
          if type.ancestors.include?(Array)
            type_info = type.class.type_info
            [type_info.version, "ArrayOf#{type_info.wsdl_name}"]
          else
            namespace = wsdl_namespace(type.version)
            [namespace, type.type_info.wsdl_name]
          end
        end
      end

      def wsdl_name(type)
        qualified_wsdl_name(type).last
      end
    end

    require "ruby_vim_sdk/missing_types"
    require "ruby_vim_sdk/core_types"
    require "ruby_vim_sdk/server_objects"

    load_types
  end

  DYNAMIC_TYPES = Set.new([Class, Vmodl::TypeName, Vmodl::MethodName, Vmodl::PropertyPath])
end
