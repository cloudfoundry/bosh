require_relative '../../helpers/build'
require_relative '../../helpers/pipeline'

namespace :ci do
  namespace :system do
    namespace :vsphere do
      task :micro do
        cd(ENV['WORKSPACE']) do
          begin
            pipeline = Bosh::Helpers::Pipeline.new
            pipeline.download_latest_stemcell(infrastructure: 'vsphere', name: 'micro-bosh-stemcell')
            pipeline.download_latest_stemcell(infrastructure: 'vsphere', name: 'bosh-stemcell')
            Rake::Task['spec:system:vsphere:micro'].invoke
          ensure
            rm_f(Dir.glob('*bosh-stemcell-*.tgz'))
          end
        end
      end
    end


  end
end
