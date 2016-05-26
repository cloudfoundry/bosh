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
require 'open3'
include Archive::Tar

require 'semi_semantic/version'

require 'bosh/template/evaluation_context'

unless defined?(Bosh::Cli::VERSION)
  require 'bosh/cli/version'
end

require 'common/common'
require 'common/exec'
require 'common/release/release_directory'
require 'common/version/release_version'
require 'common/version/release_version_list'
require 'common/version/bosh_version'
require 'common/version/stemcell_version'
require 'common/version/stemcell_version_list'
require 'common/thread_pool'

require 'bosh/cli/config'
require 'bosh/cli/core_ext'
require 'bosh/cli/errors'
require 'bosh/cli/glob_match'
require 'bosh/cli/yaml_helper'
require 'bosh/cli/dependency_helper'
require 'bosh/cli/deployment_manifest'
require 'bosh/cli/manifest'
require 'bosh/cli/manifest_warnings'
require 'bosh/cli/deployment_helper'
require 'bosh/cli/validation'
require 'bosh/cli/stemcell'
require 'bosh/cli/client/director'
require 'bosh/cli/client/credentials'
require 'bosh/cli/director_task'

require 'bosh/cli/line_wrap'
require 'bosh/cli/backup_destination_path'
require 'bosh/cli/interactive_progress_renderer'
require 'bosh/cli/non_interactive_progress_renderer'

require 'bosh/cli/source_control/git_ignore'

require 'bosh/cli/versions/versions_index'
require 'bosh/cli/versions/local_artifact_storage'
require 'bosh/cli/versions/release_versions_index'
require 'bosh/cli/versions/releases_dir_migrator'
require 'bosh/cli/versions/version_file_resolver'
require 'bosh/cli/versions/multi_release_support'

require 'bosh/cli/archive_builder'
require 'bosh/cli/archive_repository_provider'
require 'bosh/cli/archive_repository'
require 'bosh/cli/build_artifact'
require 'bosh/cli/resources/job'
require 'bosh/cli/resources/license'
require 'bosh/cli/resources/package'
require 'bosh/cli/changeset_helper'
require 'bosh/cli/deployment_manifest_compiler'
require 'bosh/cli/task_tracking'

require 'bosh/cli/release'
require 'bosh/cli/release_archiver'
require 'bosh/cli/release_builder'
require 'bosh/cli/release_compiler'
require 'bosh/cli/release_tarball'
require 'bosh/cli/sorted_release_archiver'

require 'bosh/cli/blob_manager'

require 'bosh/cli/logs_downloader'

require 'bosh/cli/job_property_collection'
require 'bosh/cli/job_property_validator'

require 'bosh/cli/command_discovery'
require 'bosh/cli/command_handler'
require 'bosh/cli/runner'
require 'bosh/cli/base_command'

require 'bosh/cli/client/uaa/token_provider'
require 'bosh/cli/client/uaa/auth_info'

tmpdir = Dir.mktmpdir
at_exit { FileUtils.rm_rf(tmpdir) }
ENV['TMPDIR'] = tmpdir

Dir[File.dirname(__FILE__) + '/cli/commands/**/*.rb'].each do |file|
  require file
end
