# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class JobPropertyCollection
    include Enumerable

    # @param [JobBuilder] job_builder Which job this property collection is for
    # @param [Hash] global_properties Globally defined properties
    # @param [Hash] job_properties Properties defined for this job only
    # @param [Hash] mappings Property mappings for this job
    def initialize(job_builder, global_properties, job_properties, mappings)
      @job_builder = job_builder

      @job_properties = deep_copy(job_properties || {})
      merge(@job_properties, deep_copy(global_properties))

      @mappings = mappings || {}
      @properties = []

      resolve_mappings
      filter_properties
    end

    def each
      @properties.each { |property| yield property }
    end

    # @return [Hash] Property hash (keys are property name components)
    def to_hash
      @properties
    end

    private

    def resolve_mappings
      @mappings.each_pair do |to, from|
        resolved = lookup_property(@job_properties, from)

        if resolved.nil?
          raise InvalidPropertyMapping,
                "Cannot satisfy property mapping `#{to}: #{from}', " +
                "as `#{from}' is not in deployment properties"
        end

        @job_properties[to] = resolved
      end
    end

    # @return [void] Modifies @properties
    def filter_properties
      if @job_builder.properties.empty?
        # If at least one template doesn't have properties defined, we
        # need all properties to be available to job (backward-compatibility)
        @properties = @job_properties
        return
      end

      @properties = {}

      @job_builder.properties.each_pair do |name, definition|
        copy_property(
          @properties, @job_properties, name, definition["default"])
      end
    end

    private

    # TODO: CLI shares these helpers with director, so we should probably
    #       extract them to 'bosh-common'

    # Copies property with a given name from src to dst.
    # @param [Hash] dst Property destination
    # @param [Hash] src Property source
    # @param [String] name Property name (dot-separated)
    # @param [Object] default Default value (if property is not in src)
    def copy_property(dst, src, name, default)
      keys = name.split(".")
      src_ref = src
      dst_ref = dst

      keys.each do |key|
        src_ref = src_ref[key]
        break if src_ref.nil? # no property with this name is src
      end

      keys[0..-2].each do |key|
        dst_ref[key] ||= {}
        dst_ref = dst_ref[key]
      end

      dst_ref[keys[-1]] ||= {}
      dst_ref[keys[-1]] = src_ref || default
    end

    # @param [Hash] collection Property collection
    # @param [String] name Dot-separated property name
    def lookup_property(collection, name)
      keys = name.split(".")
      ref = collection

      keys.each do |key|
        ref = ref[key]
        return nil if ref.nil?
      end

      ref
    end

    # @param [Object] object Serializable object
    # @return [Object] Deep copy of the object
    def deep_copy(object)
      Marshal.load(Marshal.dump(object))
    end

    # @param [Hash] base
    # @param [Hash] extras
    # @return [void] Modifies base
    def merge(base, extras)
      base.merge!(extras) do |_, old_value, new_value|
        if old_value.is_a?(Hash) && new_value.is_a?(Hash)
          merge(old_value, new_value)
        end

        old_value
      end
    end

  end
end
