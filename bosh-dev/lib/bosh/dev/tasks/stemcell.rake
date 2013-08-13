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
    require 'bosh/dev/gems_generator'

    options = Bosh::Dev::StemcellRakeMethods.new.default_options(args.to_hash)

    Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir

    Bosh::Dev::StemcellRakeMethods.new.build("stemcell-#{args[:infrastructure]}", options)
  end

  desc 'Build micro bosh stemcell'
  task :micro, [:tarball, :infrastructure, :version, :stemcell_tgz, :disk_size] do |t, args|
    require 'bosh/dev/micro_bosh_release'
    require 'bosh/dev/build'
    require 'bosh/dev/stemcell_rake_methods'
    require 'bosh/dev/gems_generator'

    options = Bosh::Dev::StemcellRakeMethods.new.default_options(args.to_hash)
    if args[:tarball]
      release_tarball = args[:tarball]
      options[:agent_gem_src_url] = Bosh::Dev::Build.candidate.gems_dir_url
    else
      Bosh::Dev::GemsGenerator.new.build_gems_into_release_dir
      release = Bosh::Dev::MicroBoshRelease.new
      release_tarball = release.tarball
    end

    options[:stemcell_name] ||= 'micro-bosh-stemcell'

    options = options.merge(Bosh::Dev::StemcellRakeMethods.new.bosh_micro_options(args[:infrastructure], release_tarball))

    Bosh::Dev::StemcellRakeMethods.new.build("stemcell-#{args[:infrastructure]}", options)
  end
end
