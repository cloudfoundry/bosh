module Bosh
  module Cli
    DEFAULT_CONFIG_PATH = File.expand_path('~/.bosh_config')
  end
end

autoload :HTTPClient, 'httpclient'

require 'blobstore_client'
require 'base64'
require 'digest/sha1'
require 'fileutils'
require 'highline/import'
require 'json'
require 'monitor'
require 'optparse'
require 'ostruct'
require 'pathname'
require 'progressbar'
require 'resolv'
require 'set'
require 'tempfile'
require 'terminal-table/import'
require 'time'
require 'timeout'
require 'tmpdir'
require 'uri'
require 'yaml'
require 'netaddr'
require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

unless defined?(Bosh::Cli::VERSION)
  require 'cli/version'
end

require 'common/common'
require 'common/exec'
require 'common/version/release_version'
require 'common/version/bosh_version'
require 'common/version/stemcell_version'
require 'common/properties'

require 'cli/config'
require 'cli/core_ext'
require 'cli/errors'
require 'cli/yaml_helper'
require 'cli/dependency_helper'
require 'cli/deployment_manifest'
require 'cli/manifest_warnings'
require 'cli/deployment_helper'
require 'cli/validation'
require 'cli/stemcell'
require 'cli/client/director'
require 'cli/director_task'

require 'cli/line_wrap'
require 'cli/backup_destination_path'

require 'cli/versions_index'
require 'cli/packaging_helper'
require 'cli/package_builder'
require 'cli/job_builder'
require 'cli/changeset_helper'
require 'cli/deployment_manifest_compiler'
require 'cli/task_tracking'

require 'cli/release'
require 'cli/release_builder'
require 'cli/release_compiler'
require 'cli/release_tarball'

require 'cli/blob_manager'

require 'cli/logs_downloader'

require 'cli/job_property_collection'
require 'cli/job_property_validator'

require 'cli/command_discovery'
require 'cli/command_handler'
require 'cli/runner'
require 'cli/base_command'

tmpdir = Dir.mktmpdir
at_exit { FileUtils.rm_rf(tmpdir) }
ENV['TMPDIR'] = tmpdir

Dir[File.dirname(__FILE__) + '/cli/commands/*.rb'].each do |file|
  require file
end
