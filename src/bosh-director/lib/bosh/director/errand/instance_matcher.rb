module Bosh::Director
  class Errand::InstanceMatcher
    def initialize(requested_instance_filters)
      @matched_requests = Set.new
      @filters = requested_instance_filters.map do |req|
        if req.is_a?(Hash)
          Errand::InstanceFilter.new(req['group'], req['id'], req)
        else
          Errand::InstanceFilter.new(nil, nil, req)
        end
      end
    end

    def match(instances)
      return instances, @filters.map(&:original) if @filters.empty?
      return [], [] if instances.empty?

      results = Set.new
      applied_filters = Set.new

      @filters.each do |filter|
        matched_instances = instances.select{|instance| filter.matches?(instance, instances)}
        results += matched_instances

        if !matched_instances.empty?
          applied_filters.add(filter)
        end
      end

      return results.to_a, (@filters-applied_filters.to_a).compact.map(&:original)
    end

  end

  class Errand::InstanceFilter
    attr_reader :original

    def initialize(group_name, index_or_id, original)
      @group_name = group_name
      @index_or_id = index_or_id
      @original = original
    end

    def matches?(instance, all_instances)
      if @index_or_id.nil? || @index_or_id.empty?
        return instance.job == @group_name
      end

      if @index_or_id == 'first' && instance.job == @group_name
        instances_in_group = all_instances.select { |i| i.job == @group_name }
        return instances_in_group.map(&:uuid).sort.first == instance.uuid
      end

      instance.job == @group_name &&
        (instance.uuid == @index_or_id || instance.index.to_s == @index_or_id.to_s )
    end
  end
end

