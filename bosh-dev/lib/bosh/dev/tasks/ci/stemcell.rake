namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_environment'
      require 'bosh/dev/stemcell_publisher'

      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('micro', args[:infrastructure])
      stemcell_builder = Bosh::Dev::StemcellBuilder.new(stemcell_environment)

      publisher = Bosh::Dev::StemcellPublisher.new
      publisher.publish(stemcell_builder.micro)
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_environment'
      require 'bosh/dev/stemcell_publisher'

      stemcell_environment = Bosh::Dev::StemcellEnvironment.new('basic', args[:infrastructure])
      stemcell_builder = Bosh::Dev::StemcellBuilder.new(stemcell_environment)

      publisher = Bosh::Dev::StemcellPublisher.new
      publisher.publish(stemcell_builder.basic)
    end
  end
end
