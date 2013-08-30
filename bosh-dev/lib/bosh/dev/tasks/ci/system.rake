require 'bosh/dev/bat_helper'

namespace :ci do
  namespace :system do
    task :micro, [:infrastructure, :net_type] do |_, args|
      Bosh::Dev::BatHelper.new(args.infrastructure, args.net_type).run_rake
    end
  end
end
