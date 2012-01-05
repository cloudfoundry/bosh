module Bosh::Cli
  module VersionCalc

    # Returns 0 if two versions are the same,
    # 1 if v1 > v2
    # -1 if v1 < v2
    def version_cmp(v1 = "0", v2 = "0")
      vp1 = components(v1)
      vp2 = components(v2)

      [vp1.size, vp2.size].max.times do |i|
        result = vp1[i].to_i <=> vp2[i].to_i
        return result unless result == 0
      end

      0
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
      components(v)[0].to_i
    end

    def minor_version(v)
      components(v)[1].to_i
    end

    private

    def components(v)
      v.to_s.split(".")
    end

  end
end
