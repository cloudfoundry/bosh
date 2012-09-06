# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Common
  # Helper class to evaluate templates. Used by Director, CLI and Agent.
  class TemplateEvaluationContext
    include PropertyHelper

    # @return [String] Template name
    attr_reader :name

    # @return [Integer] Template instance index
    attr_reader :index

    # @return [Hash] Template properties
    attr_reader :properties

    # @return [Hash] Template spec
    attr_reader :spec

    # @param [Hash] spec Template spec
    def initialize(spec)
      unless spec.is_a?(Hash)
        raise TemplateEvaluationFailed,
              "Invalid spec provided for template evaluation context, " +
              "Hash expected, #{spec.class} given"
      end

      if spec["job"].is_a?(Hash)
        @name = spec["job"]["name"]
      else
        @name = nil
      end

      @index = spec["index"]
      @spec = openstruct(spec)
      @raw_properties = spec["properties"] || {}
      @properties = openstruct(@raw_properties)
    end

    # @return [Binding] Template binding
    def get_binding
      binding.taint
    end

    # Property lookup helper
    # @param [String] name Property name
    # @param [optional, Object] default Default value
    # @return [Object] Property value
    def p(name, default = nil)
      result = lookup_property(@raw_properties, name)
      if result.nil?
        return default if default
        raise UnknownProperty.new(name)
      end
      result
    end

    # Run a block of code if all given properties are defined
    # @param [Array<String>] names Property names
    # @yield [Object] property values
    def if_p(*names)
      values = names.map do |name|
        value = lookup_property(@raw_properties, name)
        return if value.nil?
        value
      end

      yield *values
    end

    # @return [Object] Object representation where all hashes are unrolled
    #   into OpenStruct objects. This exists mostly for backward
    #   compatibility, as it doesn't provide good error reporting.
    def openstruct(object)
      case object
        when Hash
          mapped = object.inject({}) { |h, (k,v)| h[k] = openstruct(v); h }
          OpenStruct.new(mapped)
        when Array
          object.map { |item| openstruct(item) }
        else
          object
      end
    end
  end
end