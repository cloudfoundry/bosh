# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  module VersionCalc

    # Returns 0 if two versions are the same,
    # 1 if v1 > v2
    # -1 if v1 < v2
    def version_cmp(v1 = "0", v2 = "0")
      VersionNumber.new(v1) <=> VersionNumber.new(v2)
    end

    def version_greater(v1, v2)
      version_cmp(v1, v2) > 0
    end

    def version_less(v1, v2)
      version_cmp(v1, v2) < 0
    end

    def version_same(v1, v2)
      version_cmp(v1, v2) == 0
    end

    def major_version(v)
      VersionNumber.new(v).major
    end

    def minor_version(v)
      VersionNumber.new(v).minor
    end
  end

  class VersionNumber
    include Comparable

    attr_reader :version

    def initialize(version_value)
      @version = version_value.to_s
    end

    def <=>(other)
      v1 = version
      v2 = other.version
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
      version.split('.')
    end
  end
end
