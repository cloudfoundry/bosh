module Bosh::Director
  class Errand::InstanceMatcher
    def initialize(requested_slug_strings)
      @matched_requests = Set.new
      @slugs = requested_slug_strings.map do |req|
        Errand::InstanceSlug.fromSlugString(req)
      end
    end

    def matches?(instance)
      return true if @slugs.empty?
      found = false
      @slugs.each do |slug|
        if slug.matches?(instance)
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
    def self.fromSlugString(slugString)
      group_name, indexOrId = slugString.split('/')
      new(group_name, indexOrId, slugString)
    end

    def initialize(group_name, indexOrId, original)
      @group_name = group_name
      @indexOrId = indexOrId
      @original = original
    end

    def matches?(instance)
      if @indexOrId.nil? || @indexOrId.empty?
        return instance.job_name == @group_name
      end
      instance.job_name == @group_name &&
        (instance.uuid == @indexOrId || instance.index.to_s == @indexOrId.to_s)
    end

    def to_s
      @original
    end
  end
end

