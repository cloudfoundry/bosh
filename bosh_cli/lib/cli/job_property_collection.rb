# Copyright (c) 2009-2012 VMware, Inc.

require 'common/deep_copy'
require 'bosh/template/property_helper'

module Bosh::Cli
  class JobPropertyCollection
    include Enumerable
    include Bosh::Template::PropertyHelper

    # @param [Bosh::Cli::Resources::Job] job Which job this property collection is for
    # @param [Hash] global_properties Globally defined properties
    # @param [Hash] job_properties Properties defined for this job only
    # @param [Hash] mappings Property mappings for this job
    def initialize(job, global_properties, job_properties, mappings)
      @job = job

      @job_properties = Bosh::Common::DeepCopy.copy(job_properties || {})
      merge(@job_properties, Bosh::Common::DeepCopy.copy(global_properties))

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
                "Cannot satisfy property mapping '#{to}: #{from}', " +
                "as '#{from}' is not in deployment properties"
        end

        @job_properties[to] = resolved
      end
    end

    # @return [void] Modifies @properties
    def filter_properties
      if @job.properties.empty?
        # If at least one template doesn't have properties defined, we
        # need all properties to be available to job (backward-compatibility)
        @properties = @job_properties
        return
      end

      @properties = {}

      @job.properties.each_pair do |name, definition|
        copy_property(
          @properties, @job_properties, name, definition["default"])
      end
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
