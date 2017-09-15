module Bosh::Director
  class Errand::InstanceMatcher
    def initialize(requested_instance_filters)
      @matched_requests = Set.new
      @filters = requested_instance_filters.map do |req|
        if req.is_a?(Hash)
          Errand::InstanceFilter.new(req['group'], req['id'], req)
        else
          Errand::InstanceFilter.new(nil,nil, req)
        end
      end
    end

    def match(instance_groups)
      return Hash[instance_groups.collect{|instance_group| [instance_group,instance_group.instances] }], [] if @filters.empty?
      results = {}
      applied_filters = Set.new

      @filters.each do |filter|
        instance_groups.each do |instance_group|
          matched_instances = instance_group.instances.select{|instance| filter.matches?(instance, instance_group.instances)}
          if !matched_instances.empty?
            if results.key?(instance_group)
              results[instance_group] = results[instance_group].merge(matched_instances)
            else
              results[instance_group] = Set.new(matched_instances)
            end
          end

          if filter.match_instance_group(instance_group) || !matched_instances.empty?
            applied_filters.add(filter)
          end
        end
      end
      return results.update(results){|key,value| results[key]=value.to_a}, (@filters-applied_filters.to_a).compact.map(&:original)
    end

  end

  class Errand::InstanceFilter
    attr_reader :original

    def initialize(group_name, index_or_id, original)
      @group_name = group_name
      @index_or_id = index_or_id
      @original = original
    end

    def match_instance_group(instance_group)
      @group_name == instance_group.name  && @index_or_id.nil?
    end

    def matches?(instance, instances_in_group)
      if @index_or_id.nil? || @index_or_id.empty?
        return instance.job_name == @group_name
      end

      if @index_or_id == 'first' && instance.job_name == @group_name
        return instances_in_group.map(&:uuid).sort.first == instance.uuid
      end

      instance.job_name == @group_name &&
        (instance.uuid == @index_or_id || instance.index.to_s == @index_or_id.to_s )
    end
  end
end

