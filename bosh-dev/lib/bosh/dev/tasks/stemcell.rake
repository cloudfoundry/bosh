# Copyright (c) 2009-2012 VMware, Inc.

require 'bosh_agent'
require 'rbconfig'
require 'atmos'
require 'json'
require 'rugged'

namespace :stemcell do
  desc 'Build stemcell'
  task :basic, [:infrastructure, :version, :stemcell_tgz, :disk_size] do |_, args|
    require 'bosh/dev/stemcell_rake_methods'

    options = Bosh::Dev::StemcellRakeMethods.new.default_options(args.to_hash)
    options[:stemcell_name] ||= 'bosh-stemcell'
    options[:stemcell_tgz] = args[:stemcell_tgz]
    options[:stemcell_version] = args.with_defaults({}).fetch(:version)

    Rake::Task['all:finalize_release_directory'].invoke

    Bosh::Dev::StemcellRakeMethods.new.build("stemcell-#{args[:infrastructure]}", options)
  end

  desc 'Build micro bosh stemcell'
  task :micro, [:tarball, :infrastructure, :version, :stemcell_tgz, :disk_size] do |t, args|
    require 'bosh/dev/micro_bosh_release'
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_rake_methods'

    manifest =
      File.join(
        File.expand_path(
          File.dirname(__FILE__)
        ), '..', '..', '..', '..', '..', 'release', 'micro', "#{args[:infrastructure]}.yml"
      )

    options = Bosh::Dev::StemcellRakeMethods.new.default_options(args.to_hash)
    options[:stemcell_version] = args.with_defaults({}).fetch(:version)
    if args[:tarball]
      release_tarball = args[:tarball]
      options[:agent_gem_src_url] = Bosh::Dev::Build.candidate.gems_dir_url
    else
      Rake::Task['all:finalize_release_directory'].invoke
      release = Bosh::Dev::MicroBoshRelease.new
      release_tarball = release.tarball
    end

    options[:stemcell_name] ||= 'micro-bosh-stemcell'
    options[:stemcell_tgz] = args[:stemcell_tgz]

    options = options.merge(Bosh::Dev::StemcellRakeMethods.new.bosh_micro_options(manifest, release_tarball))
    options[:non_interactive] = true

    Bosh::Dev::StemcellRakeMethods.new.build("stemcell-#{args[:infrastructure]}", options)
  end
end
