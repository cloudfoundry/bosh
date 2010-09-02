module Bosh::Director
  module DeepCopy
    def _deep_copy
      Marshal::load(Marshal::dump(self))
    end
  end
end