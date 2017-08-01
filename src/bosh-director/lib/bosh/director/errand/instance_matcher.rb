module Bosh::Director
  class Errand::InstanceMatcher
    def initialize(requested_slug_strings)
      @matched_requests = Set.new
      @slugs = requested_slug_strings.map do |req|
        Errand::InstanceSlug.from_slug_string(req)
      end
    end

    def matches?(instance, instances_in_group)
      return true if @slugs.empty?
      found = false
      @slugs.each do |slug|
        if slug.matches?(instance, instances_in_group)
          @matched_requests.add(slug)
          found = true
        end
      end
      found
    end

    def unmatched_criteria
      (@slugs - @matched_requests.to_a).map(&:to_s)
    end
  end

  class Errand::InstanceSlug
    def self.from_slug_string(slug_string)
      group_name, index_or_id = slug_string.split('/')
      new(group_name, index_or_id, slug_string)
    end

    def initialize(group_name, index_or_id, original)
      @group_name = group_name
      @index_or_id = index_or_id
      @original = original
    end

    def matches?(instance, instances_in_group)
      if @index_or_id.nil? || @index_or_id.empty?
        return instance.job_name == @group_name
      end

      if @index_or_id == 'first' && instance.job_name == @group_name
        return instances_in_group.map(&:uuid).sort.first == instance.uuid
      end

      instance.job_name == @group_name &&
        (instance.uuid == @index_or_id || instance.index.to_s == @index_or_id.to_s)
    end

    def to_s
      @original
    end
  end
end

