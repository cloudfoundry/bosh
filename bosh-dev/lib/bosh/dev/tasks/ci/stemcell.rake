namespace :ci do
  namespace :stemcell do
    desc 'Build micro bosh stemcell from CI pipeline'
    task :micro, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_publisher'

      stemcell_builder = Bosh::Dev::StemcellBuilder.new('micro', args[:infrastructure])
      publisher = Bosh::Dev::StemcellPublisher.new
      publisher.publish(stemcell_builder.build)
    end

    desc 'Build stemcell from CI pipeline'
    task :basic, [:infrastructure] do |t, args|
      require 'bosh/dev/stemcell_builder'
      require 'bosh/dev/stemcell_publisher'

      stemcell_builder = Bosh::Dev::StemcellBuilder.new('basic', args[:infrastructure])
      publisher = Bosh::Dev::StemcellPublisher.new
      publisher.publish(stemcell_builder.build)
    end
  end
end
