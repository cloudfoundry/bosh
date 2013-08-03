require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/stemcell/stemcell'

namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_environment'
      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('micro', args[:infrastructure])
      stemcell_environment.sanitize
      stemcell_environment.create_micro_stemcell
      stemcell_environment.publish
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_environment'
      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('basic', args[:infrastructure])
      stemcell_environment.sanitize
      stemcell_environment.create_basic_stemcell
      stemcell_environment.publish
    end
  end
end
