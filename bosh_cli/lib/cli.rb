# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli
    DEFAULT_CONFIG_PATH = File.expand_path("~/.bosh_config")
    DEFAULT_CACHE_DIR = File.expand_path("~/.bosh_cache")
  end
end

autoload :HTTPClient, "httpclient"

require "blobstore_client"
require "base64"
require "digest/sha1"
require "fileutils"
require "highline/import"
require "json"
require "monitor"
require "optparse"
require "ostruct"
require "pathname"
require "progressbar"
require "resolv"
require "set"
require "tempfile"
require "terminal-table/import"
require "time"
require "timeout"
require "tmpdir"
require "uri"
require "yaml"
require "netaddr"
require "zlib"
require "archive/tar/minitar"
require "haddock"
Haddock::Password.delimiters='!@#%^&()-,./'
include Archive::Tar

unless defined?(Bosh::Cli::VERSION)
  require "cli/version"
end

require "common/common"
require "common/exec"

require "cli/config"
require "cli/core_ext"
require "cli/errors"
require "cli/yaml_helper"
require "cli/version_calc"
require "cli/dependency_helper"
require "cli/deployment_helper"
require "cli/validation"
require "cli/cache"
require "cli/stemcell"
require "cli/director"
require "cli/director_task"

require "cli/versions_index"
require "cli/packaging_helper"
require "cli/package_builder"
require "cli/job_builder"
require "cli/changeset_helper"
require "cli/task_tracker"
require "cli/task_log_renderer"
require "cli/event_log_renderer"
require "cli/null_renderer"
require "cli/deployment_manifest_compiler"

require "cli/release"
require "cli/release_builder"
require "cli/release_compiler"
require "cli/release_tarball"

require "cli/blob_manager"

require "common/properties"
require "cli/job_property_collection"
require "cli/job_property_validator"

require "cli/command_discovery"
require "cli/command_handler"
require "cli/runner"
require "cli/base_command"

tmpdir = Dir.mktmpdir
at_exit { FileUtils.rm_rf(tmpdir) }
ENV["TMPDIR"] = tmpdir

Dir[File.dirname(__FILE__) + "/cli/commands/*.rb"].each do |file|
  require file
end
