require "nokogiri"

module VCloudSdk
  module Xml

    class WrapperFactory
      @@xml_dictionary = {}
      class << self
        def wrap_document(xml, ns = nil, namespace_defintions = nil, *args)
          doc = Nokogiri::XML(xml)
          type_name = doc.root.name
          node_class = find_wrapper_class(type_name)
          node_class.new(doc, ns, namespace_defintions, *args)
        end

        def wrap_node(node, ns, namespace_defintions = nil, *args)
          type_name = node.node_name
          node_class = find_wrapper_class(type_name)
          node_class.new(node, ns, namespace_defintions, *args)
        end

        def wrap_nodes(nodes, ns, namespace_defintions)
          nodes.collect { |node| WrapperFactory.wrap_node(node, ns,
            namespace_defintions) }
        end

        # TODO: We might run into a bug later if there are ever XML node types
        # of the same name but different namespace
        def find_wrapper_class(type_name)
          # for Ruby 1.9, we would need pass false in as the 2nd parameter
          if Xml.constants.find { |c| c.to_sym == type_name.to_sym }
            Xml.const_get(type_name.to_sym)
          else
            Wrapper
          end
        end

        def create_instance(type_name, ns = nil, namespace_defintions = nil,
            *args)
          xml = @@xml_dictionary[type_name]
          if (xml)
            wrap_document(xml, ns, namespace_defintions, *args)
          else
            raise CpiError,
              "XML type #{type_name} not found in xml_templates dir."
          end
        end

        # Load all the XML files
        Dir[File.dirname(__FILE__) + "/xml_templates/*.xml"].each do |f|
          @@xml_dictionary[File.basename(f, ".xml")] =
            File.open(File.expand_path(f)).read
        end
      end
    end

    class Wrapper
      # Because we are wrapping individual nodes in a wrapper and turning them
      # into XML docs, we need to preserve the namespace information with each
      # node
      def initialize(xml, ns = nil, ns_definitions = nil)
        if xml.is_a?(Nokogiri::XML::Document)
          @doc = xml
          @root = @doc.root
        else
          @root = xml
        end
        if ns
          @ns = ns
        else
          @ns = @root.namespace
        end

        # Use (server) supplied prefixes defaulting to the preset ones for
        # those not specified.
        @doc_namespaces = ns_definitions.nil? ? Array.new :
          Array.new(ns_definitions)
        if @root.namespace_definitions
          @doc_namespaces.concat(@root.namespace_definitions)
        end
      end

      def doc_namespaces
        @doc_namespaces
      end

      def xpath(*args)
        WrapperFactory::wrap_nodes(@root.xpath(*args), @ns, @doc_namespaces)
      end

      def href
        @root["href"]
      end

      def name
        @root["name"]
      end

      def urn
        @root["id"]
      end

      def type
        @root["type"]
      end

      def create_xpath_query(type_name, attrs = nil, only_immediate = false,
          namespace = VCLOUD_NAMESPACE)
        qualified_name = create_qualified_name(type_name, namespace)
        depth_prefix = only_immediate ? nil : ".//"
        if attrs && attrs.length > 0
          attrs_list = []
          attrs.each do |k,v|
            attrs_list.push(%Q[@#{k}="#{v}"])
          end

          "#{depth_prefix}#{qualified_name}[#{attrs_list.join(" and ")}]"
        else
          "#{depth_prefix}#{qualified_name}"
        end
      end

      def create_qualified_name(name, href)
        namespace_wanted = nil
        ns_wanted_no_prefix = nil
        # Do it this way so the namespaces are searched in the order they are
        # added.  The first one is the one closest to the node, while the ones
        # at the document root are the last.
        @doc_namespaces.each do |ns|
          if ns.href == href
            if ns.prefix.nil?
              ns_wanted_no_prefix = ns;
            else
              namespace_wanted = ns
              break
            end
          end
        end
        namespace_wanted = ns_wanted_no_prefix unless namespace_wanted
        raise CpiError, "Namespace #{href} not found." unless namespace_wanted
        ns_prefix = namespace_wanted.prefix.nil? ? "xmlns" :
          namespace_wanted.prefix
        "#{ns_prefix}:#{name}"
      end

      def get_nodes(type_name, attrs = nil, only_immediate = false,
          namespace = VCLOUD_NAMESPACE)
        xpath(create_xpath_query(type_name, attrs, only_immediate, namespace))
      end

      # There seem to be a Nokogiri bug such that attribute's namespace
      # prefixes are ignored.  For example, to return an attribute named
      # vcloud:capacity, use "capacity", not "vcloud:capacity".
      def [](attr)
        @root[attr]
      end

      def []=(attr, value)
        @root[attr] = value
      end

      def content
        @root.content
      end

      def content=(value)
        @root.content = value
      end

      def ==(other)
        @root.to_s == other.node.to_s
      end

      def to_s
        add_namespaces.to_xml.each_line.inject("") {
          |xml, line| xml.concat(line.sub(/^\s+$/, "")) }
      end

      def add_child(child, namespace_prefix = nil, namespace_href = nil,
          parent = @root)
        if child.is_a? Wrapper
          @root.add_child(child.node)
        elsif child.is_a? String
          node = Nokogiri::XML::Node.new(child, parent)
          if (namespace_prefix.nil? ^ namespace_href.nil?)
            raise CpiError,
              "Namespace prefix must both be nil or defined together."
          end
          # This is a little more cumbersome but Nokogiri has problems
          # figuring out the right namespace prefix otherwise
          if namespace_prefix
            ns = node.add_namespace_definition(namespace_prefix,
              namespace_href)
            node.namespace = ns
          end
          parent.add_child(node)
        else
          raise CpiError, "Cannot add child.  Unknown object passed in."
        end
      end

      # Creates a child node but does not add it to the document.  Used when
      # a new child node has to be in a specific location or order.
      def create_child(tag)
        Nokogiri::XML::Node.new(tag, @root)
      end

      protected

      def node
        @root
      end

      def namespace
        @ns
      end

      def namespace_definitions
        @doc_namespaces
      end

      private

      def add_namespaces
        clone = @root.clone

        # This is a workaround for a Nokogiri bug.  If you add a namespace
        # with a nil for prefix, i.e. the namespace following xmlns, Nokogiri
        # will remove the original namespace and assume you are setting a new
        # namespace for the node.
        default_ns = clone.namespace

        @doc_namespaces.each do |ns|
          clone.add_namespace_definition(ns.prefix, ns.href)
        end
        clone.namespace = default_ns
        clone
      end
    end

  end
end
