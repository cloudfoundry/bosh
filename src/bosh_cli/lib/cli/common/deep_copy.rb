module Bosh::Cli::Common
  module DeepCopy
    def self.copy(object)
      Marshal.load(Marshal.dump(object))
    end
  end
end
