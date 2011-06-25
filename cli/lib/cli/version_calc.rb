module Bosh::Cli
  module VersionCalc

    # Returns 0 if two versions are the same,
    # 1 if v1 > v2
    # -1 if v1 < v2
    def version_cmp(v1 = "0", v2 = "0")
      vp1 = "#{v1}.0".split(".")
      vp2 = "#{v2}.0".split(".")

      [vp1.size, vp2.size].max.times do |i|
        result = vp1[i].to_i <=> vp2[i].to_i
        return result unless result == 0
      end

      0
    end

    def version_greater(v1, v2)
      version_cmp(v1, v2) > 0
    end

    def version_same(v1, v2)
      version_cmp(v1, v2) == 0
    end

  end
end
