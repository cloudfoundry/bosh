require 'bosh/dev/bat_helper'

namespace :ci do
  namespace :system do
    task :micro, [:infrastructure_name, :operating_system_name, :net_type] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).deploy_microbosh_and_run_bats
    end

    task :existing_micro, [:infrastructure_name, :operating_system_name, :net_type] do |_, args|
      Bosh::Dev::BatHelper.for_rake_args(args).run_bats
    end
  end
end
