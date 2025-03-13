module Bosh::Director::DeploymentPlan
  class Variables

    def initialize(spec)
      @spec = spec || []
    end

    def get_variable(name)
      result = @spec.find { |variable| variable['name'] == name }
      result ? Bosh::Director::DeepCopy.copy(result) : result
    end

    def contains_variable?(name)
      @spec.any? { |variable| variable['name'] == name }
    end

    def spec
      Bosh::Director::DeepCopy.copy(@spec)
    end

    def add(variables)
      @spec.concat(variables.spec)
    end
  end
end
