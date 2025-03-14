SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << SPEC_ROOT

require File.expand_path('../../spec/shared/spec_helper', SPEC_ROOT)

require 'logging'

require 'bosh/common'
require 'bosh/common/exec'
require 'bosh/common/thread_pool'

def asset_path(name)
  File.join(SPEC_ROOT, 'assets', name)
end
