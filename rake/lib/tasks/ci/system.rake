require_relative '../../helpers/build'
require_relative '../../helpers/pipeline'

namespace :ci do
  namespace :system do
    task :micro, [:infrastructure] do |_, args|
      infrastructure = args.infrastructure || abort('infrastructure is a required parameter')
      %w{aws openstack vsphere}.include?(infrastructure) || abort("invalid infrastructure: #{infrastructure}")

      cd(ENV['WORKSPACE']) do
        begin
          ENV['BAT_INFRASTRUCTURE'] = infrastructure
          pipeline = Bosh::Helpers::Pipeline.new
          pipeline.download_latest_stemcell(infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: infrastructure.match('aws'))
          pipeline.download_latest_stemcell(infrastructure: infrastructure, name: 'bosh-stemcell', light: infrastructure.match('aws'))
          Rake::Task["spec:system:#{infrastructure}:micro"].invoke
        ensure
          rm_f(Dir.glob('*bosh-stemcell-*.tgz'))
        end
      end
    end
  end
end
