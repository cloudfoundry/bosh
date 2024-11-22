SPEC_ROOT = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH << SPEC_ROOT

require File.expand_path('../../spec/shared/spec_helper', SPEC_ROOT)

require 'logging'
require 'tmpdir'

require 'common/common'
require 'common/exec'
require 'common/deep_copy'
require 'common/logging/regex_filter'
require 'common/logging/filters'
require 'common/ssl'
require 'common/version/bosh_version'
require 'common/version/release_version'
require 'common/version/release_version_list'
require 'common/version/version_list'
require 'common/version/stemcell_version'
require 'common/version/stemcell_version_list'
require 'common/thread_pool'

def asset_path(name)
  File.join(SPEC_ROOT, 'assets', name)
end
