SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << SPEC_ROOT

require File.expand_path('../../spec/shared/spec_helper', SPEC_ROOT)

require 'logging'
require 'yaml'
require 'json'

require 'bosh/common'
require 'bosh/common/exec'
require 'bosh/common/thread_pool'

require 'bosh/common/template/evaluation_context'
require 'bosh/common/template/property_helper'
require 'bosh/common/template/test'

def asset_path(name)
  File.join(SPEC_ROOT, 'assets', name)
end

def asset_content(name)
  File.read(asset_path(name))
end