module Bosh::Common
  class VersionNumber
    include Comparable

    def initialize(version_value)
      @version = version_value.to_s
    end

    def <=>(other)
      v1 = @version
      v2 = other.to_s
      return v1 <=> v2 if [v1, v2].all? { |v| v.to_s.match(/^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$/) }

      vp1 = components
      vp2 = other.components

      [vp1.size, vp2.size].max.times do |i|
        result = vp1[i].to_i <=> vp2[i].to_i
        return result unless result == 0
      end

      0
    end

    def major
      components[0].to_i
    end

    def minor
      components[1].to_i
    end

    def components
      @version.split('.')
    end

    def to_s
      @version
    end

    def final?
      !@version.end_with?('-dev')
    end

    def next_minor
      self.class.new("#{major}.#{minor + 1}")
    end

    def dev
      final? ? self.class.new("#{@version}-dev") : self
    end
  end
end
