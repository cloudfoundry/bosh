require 'ostruct'
require 'bosh/template/evaluation_failed'
require 'bosh/template/unknown_property'
require 'bosh/template/unknown_link'
require 'bosh/template/property_helper'
require 'bosh/template/evaluation_link_instance'
require 'bosh/template/evaluation_link'
require 'bosh/template/manual_link_dns_encoder'

# Include for backward compatibility within ERB template rendering
require 'active_support'
require 'active_support/core_ext/object/blank'
require 'shellwords'

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
      def initialize(spec, dns_encoder)
        unless spec.is_a?(Hash)
          raise EvaluationFailed,
                'Invalid spec provided for template evaluation context, ' +
                    "Hash expected, #{spec.class} given"
        end

        @name = spec['name']

        @index = spec['index']
        @spec = openstruct(spec, BackCompatOpenStruct)
        @raw_properties = spec['properties'] || {}
        @properties = openstruct(@raw_properties)
        @dns_encoder = dns_encoder

        @links = spec['links'] || {}
      end

      def ==(other)
        public_members = %w[spec raw_properties name index properties]
        public_members.all? do |member|
          other.respond_to?(member) && send(member) == other.send(member)
        end
      end

      # @return [Binding] Template binding
      def get_binding
        binding
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

      # Run a block of code if all given properties are defined
      # @param [Array<String>] names Property names
      # @yield [Object] property values
      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@raw_properties, name)
          return ActiveElseBlock.new(self) if value.nil?
          value
        end

        yield(*values)
        InactiveElseBlock.new
      end

      def link(name)
        link_spec = lookup_property(@links, name)
        raise UnknownLink.new(name) if link_spec.nil?

        if link_spec.has_key?('instances')
          return create_evaluation_link(link_spec)
        end

        raise UnknownLink.new(name)
      end

      # Run a block of code if the link given exists
      # @param [String] name of the link
      # @yield [Object] link, which is an array of instances
      def if_link(name)
        link_spec = lookup_property(@links, name)
        if link_spec.nil? || !link_spec.has_key?('instances')
          ActiveElseBlock.new(self)
        else
          yield create_evaluation_link(link_spec)
          InactiveElseBlock.new
        end
      end

      private

      def create_evaluation_link(link_spec)
        link_instances = link_spec['instances'].map do |instance_link_spec|
          EvaluationLinkInstance.new(
            instance_link_spec['name'],
            instance_link_spec['index'],
            instance_link_spec['id'],
            instance_link_spec['az'],
            instance_link_spec['address'],
            instance_link_spec['properties'],
            instance_link_spec['bootstrap'],
          )
        end

        if link_spec.has_key?('address')
          encoder_to_inject = ManualLinkDnsEncoder.new(link_spec['address'])
        else
          encoder_to_inject = @dns_encoder
        end

        group_name = link_spec['instance_group']
        group_type = 'instance-group'

        if link_spec.fetch('use_link_dns_names', false)
          group_name = link_spec['group_name']
          group_type = 'link'
        end

        EvaluationLink.new(
          link_instances,
          link_spec['properties'],
          group_name,
          group_type,
          link_spec['default_network'],
          link_spec['deployment_name'],
          link_spec['domain'],
          encoder_to_inject,
          link_spec.fetch('use_short_dns_addresses', false),
        )
      end

      # @return [Object] Object representation where all hashes are unrolled
      #   into OpenStruct objects. This exists mostly for backward
      #   compatibility, as it doesn't provide good error reporting.
      def openstruct(object, open_struct_klass=OpenStruct)
        case object
          when Hash
            mapped = object.inject({}) do |h, (k, v)|
              h[k] = openstruct(v, open_struct_klass); h
            end
            open_struct_klass.new(mapped)
          when Array
            object.map { |item| openstruct(item, open_struct_klass) }
          else
            object
        end
      end

      class BackCompatOpenStruct < OpenStruct
        def methods(regular=true)
          if regular
            super(regular)
          else
            marshal_dump.keys.map(&:to_sym)
          end
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

        def else_if_p(*_names)
          InactiveElseBlock.new
        end

        def else_if_link(_name)
          InactiveElseBlock.new
        end
      end
    end
  end
end
