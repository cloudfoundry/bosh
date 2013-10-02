namespace :ci do
  namespace :system do
    task :micro, [:infrastructure_name, :operating_system_name, :net_type] do |_, args|
      require 'bosh/dev/bat_helper'
      Bosh::Dev::BatHelper.new(
        args.infrastructure_name,
        args.operating_system_name,
        args.net_type,
      ).run_rake
    end
  end
end
