require 'common/deep_copy'

module Bosh::Director::DeploymentPlan
  class Variables

    def initialize(spec)
      @spec = spec || []
    end

    def get_variable(name)
      result = @spec.find { |variable| variable['name'] == name }
      result ? Bosh::Common::DeepCopy.copy(result) : result
    end

    def contains_variable?(name)
      @spec.any? { |variable| variable['name'] == name }
    end

    def spec
      Bosh::Common::DeepCopy.copy(@spec)
    end
  end
end
