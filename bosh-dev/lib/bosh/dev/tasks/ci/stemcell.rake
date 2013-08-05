require 'bosh/dev/build'
require 'bosh/dev/pipeline'
require 'bosh/stemcell/stemcell'

namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_environment'

      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('micro', args[:infrastructure])
      stemcell_builder = Bosh::Dev::StemcellBuilder.new(stemcell_environment)

      stemcell_environment.sanitize
      stemcell_builder.micro
      stemcell_environment.publish
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_environment'

      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('basic', args[:infrastructure])
      stemcell_builder = Bosh::Dev::StemcellBuilder.new(stemcell_environment)

      stemcell_environment.sanitize
      stemcell_builder.basic
      stemcell_environment.publish
    end
  end
end
