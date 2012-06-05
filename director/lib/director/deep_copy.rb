# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module DeepCopy
    def _deep_copy
      Marshal.load(Marshal.dump(self))
    end
  end
end