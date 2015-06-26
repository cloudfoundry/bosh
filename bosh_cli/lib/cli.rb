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
autoload :Psych, 'psych'
autoload :YAML, 'yaml'
require 'netaddr'
require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

require 'semi_semantic/version'

require 'bosh/template/evaluation_context'

unless defined?(Bosh::Cli::VERSION)
  require 'cli/version'
end

require 'common/common'
require 'common/exec'
require 'common/version/release_version'
require 'common/version/release_version_list'
require 'common/version/bosh_version'
require 'common/version/stemcell_version'
require 'common/version/stemcell_version_list'
require 'common/thread_pool'

require 'cli/config'
require 'cli/core_ext'
require 'cli/errors'
require 'cli/glob_match'
require 'cli/yaml_helper'
require 'cli/dependency_helper'
require 'cli/deployment_manifest'
require 'cli/manifest'
require 'cli/manifest_warnings'
require 'cli/deployment_helper'
require 'cli/validation'
require 'cli/stemcell'
require 'cli/client/director'
require 'cli/client/credentials'
require 'cli/director_task'

require 'cli/line_wrap'
require 'cli/backup_destination_path'
require 'cli/interactive_progress_renderer'
require 'cli/non_interactive_progress_renderer'

require 'cli/source_control/git_ignore'

require 'cli/versions/versions_index'
require 'cli/versions/local_artifact_storage'
require 'cli/versions/release_versions_index'
require 'cli/versions/releases_dir_migrator'
require 'cli/versions/version_file_resolver'
require 'cli/versions/multi_release_support'

require 'cli/archive_builder'
require 'cli/archive_repository_provider'
require 'cli/archive_repository'
require 'cli/build_artifact'
require 'cli/resources/job'
require 'cli/resources/license'
require 'cli/resources/package'
require 'cli/changeset_helper'
require 'cli/deployment_manifest_compiler'
require 'cli/task_tracking'

require 'cli/release'
require 'cli/release_archiver'
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

require 'cli/client/uaa/token_provider'
require 'cli/client/uaa/auth_info'

tmpdir = Dir.mktmpdir
at_exit { FileUtils.rm_rf(tmpdir) }
ENV['TMPDIR'] = tmpdir

Dir[File.dirname(__FILE__) + '/cli/commands/**/*.rb'].each do |file|
  require file
end
