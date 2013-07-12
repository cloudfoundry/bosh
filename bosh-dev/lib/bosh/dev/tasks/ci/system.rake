require 'bosh/dev/bat_helper'

namespace :ci do
  namespace :system do
    task :micro, [:infrastructure] do |_, args|
      Bosh::Dev::BatHelper.new(ENV['WORKSPACE'], args.infrastructure).run_rake
    end
  end
end
