# Copyright (c) 2009-2012 VMware, Inc.

module Bosh
  module Cli
    DEFAULT_CONFIG_PATH = File.expand_path("~/.bosh_config")
    DEFAULT_CACHE_DIR   = File.expand_path("~/.bosh_cache")
  end
end

autoload :HTTPClient, "httpclient"
Bosh.autoload :Blobstore, "blobstore_client"

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
require "set"
require "tempfile"
require "terminal-table/import"
require "time"
require "timeout"
require "tmpdir"
require "uri"
require "yaml"
require "netaddr"
require "net/ssh"
require "net/scp"
require "net/ssh/gateway"

unless defined?(Bosh::Cli::VERSION)
  require "cli/version"
end

require "common/common"

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

require "cli/command_definition"
require "cli/runner"

YAML::ENGINE.yamler = 'syck' if defined?(YAML::ENGINE.yamler)

require File.expand_path(File.dirname(__FILE__) + "/cli/commands/base")

Dir[File.dirname(__FILE__) + "/cli/commands/*.rb"].each do |file|
  require File.expand_path(file)
end
