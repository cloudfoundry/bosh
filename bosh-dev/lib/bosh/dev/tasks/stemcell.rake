# Copyright (c) 2009-2012 VMware, Inc.

namespace :stemcell do
  desc 'Build stemcell'
  task :basic, [:infrastructure, :version, :stemcell_tgz, :disk_size] do |_, args|
    require 'bosh/dev/stemcell_rake_methods'
    stemcell_rake_methods = Bosh::Dev::StemcellRakeMethods.new(args: args.to_hash)

    stemcell_rake_methods.build_basic_stemcell
  end

  desc 'Build micro bosh stemcell'
  task :micro, [:tarball, :infrastructure, :version, :stemcell_tgz, :disk_size] do |_, args|
    require 'bosh/dev/stemcell_rake_methods'
    stemcell_rake_methods = Bosh::Dev::StemcellRakeMethods.new(args: args.to_hash)

    stemcell_rake_methods.build_micro_stemcell
  end
end
