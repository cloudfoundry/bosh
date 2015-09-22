module Bosh::Spec
  class Instance
    attr_reader :id, :is_bootstrap, :az

    def initialize(id, is_bootstrap, az)
      @id = id
      @is_bootstrap = is_bootstrap
      @az = az
    end
  end
end
