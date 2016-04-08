require 'ostruct'
require 'bosh/template/evaluation_failed'
require 'bosh/template/unknown_property'
require 'bosh/template/unknown_link'
require 'bosh/template/property_helper'
require 'bosh/template/evaluation_link_instance'
require 'bosh/template/evaluation_link'

module Bosh
  module Template
    # Helper class to evaluate templates. Used by Director, CLI and Agent.
    class EvaluationContext
      include PropertyHelper

      # @return [String] Template name
      attr_reader :name

      # @return [Integer] Template instance index
      attr_reader :index

      # @return [Hash] Template properties
      attr_reader :properties

      # @return [Hash] Raw template properties (no openstruct)
      attr_reader :raw_properties

      # @return [Hash] Template spec
      attr_reader :spec

      # @param [Hash] spec Template spec
      def initialize(spec)
        unless spec.is_a?(Hash)
          raise EvaluationFailed,
                'Invalid spec provided for template evaluation context, ' +
                    "Hash expected, #{spec.class} given"
        end

        if spec['job'].is_a?(Hash)
          @name = spec['job']['name']
        else
          @name = nil
        end

        @index = spec['index']
        @spec = openstruct(spec)
        @raw_properties = spec['properties'] || {}
        @properties = openstruct(@raw_properties)

        @links = spec['links'] || {}
      end

      # @return [Binding] Template binding
      def get_binding
        binding.taint
      end

      # Property lookup helper
      #
      # @overload p(name, default_value)
      #   Returns property value or default value if property not set
      #   @param [String] name Property name
      #   @param [Object] default_value Default value
      #   @return [Object] Property value
      #
      # @overload p(names, default_value)
      #   Returns first property from the list that is set or default value if
      #   none of them are set
      #   @param [Array<String>] names Property names
      #   @param [Object] default_value Default value
      #   @return [Object] Property value
      #
      # @overload p(names)
      #   Looks up first property from the list that is set, raises an error
      #   if none of them are set.
      #   @param [Array<String>] names Property names
      #   @return [Object] Property value
      #   @raise [Bosh::Common::UnknownProperty]
      #
      # @overload p(name)
      #   Looks up property and raises an error if it's not set
      #   @param [String] name Property name
      #   @return [Object] Property value
      #   @raise [Bosh::Common::UnknownProperty]
      def p(*args)
        names = Array(args[0])

        names.each do |name|
          result = lookup_property(@raw_properties, name)
          return result unless result.nil?
        end

        return args[1] if args.length == 2
        raise UnknownProperty.new(names)
      end

      def link(name)
        result = lookup_property(@links, name)
        raise UnknownLink.new(name) if result.nil?

        if result.has_key?("instances")
          instance_array = result["instances"].map do |link_spec|
            EvaluationLinkInstance.new(link_spec["name"], link_spec["index"], link_spec["id"], link_spec["az"], link_spec["address"], link_spec["properties"])
          end
          return EvaluationLink.new(instance_array, result["properties"])
        end
        raise UnknownLink.new(name)
      end

      # Run a block of code if all given properties are defined
      # @param [Array<String>] names Property names
      # @yield [Object] property values
      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@raw_properties, name)
          return ActiveElseBlock.new(self) if value.nil?
          value
        end

        yield *values
        InactiveElseBlock.new
      end

      # Run a block of code if the link given exists
      # @param [String] name of the link
      # @yield [Object] link, which is an array of instances
      def if_link(name)
        link_found = lookup_property(@links, name)
        if link_found.nil? || !link_found.has_key?("instances")
          return ActiveElseBlock.new(self)
        else
          instance_array = link_found["instances"].map do |link_spec|
            EvaluationLinkInstance.new(link_spec["name"], link_spec["index"], link_spec["id"], link_spec["az"], link_spec["address"], link_spec["properties"])
          end

          yield EvaluationLink.new(instance_array, link_found["properties"])
          InactiveElseBlock.new
        end
      end

      # @return [Object] Object representation where all hashes are unrolled
      #   into OpenStruct objects. This exists mostly for backward
      #   compatibility, as it doesn't provide good error reporting.
      def openstruct(object)
        case object
          when Hash
            mapped = object.inject({}) { |h, (k, v)| h[k] = openstruct(v); h }
            OpenStruct.new(mapped)
          when Array
            object.map { |item| openstruct(item) }
          else
            object
        end
      end

      class ActiveElseBlock
        def initialize(template_context)
          @context = template_context
        end

        def else
          yield
        end

        def else_if_p(*names, &block)
          @context.if_p(*names, &block)
        end

        def else_if_link(name, &block)
          @context.if_link(name, &block)
        end
      end

      class InactiveElseBlock
        def else
        end

        def else_if_p(*names)
          InactiveElseBlock.new
        end

        def else_if_link(name)
          InactiveElseBlock.new
        end
      end
    end
  end
end
