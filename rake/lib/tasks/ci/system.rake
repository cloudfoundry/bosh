require_relative '../../helpers/build'
require_relative '../../helpers/s3_stemcell'

namespace :ci do
  namespace :system do
    namespace :vsphere do
      task :micro do
        cd(ENV['WORKSPACE']) do
          begin
            Bosh::Helpers::S3Stemcell.new('vsphere', 'micro').download_latest
            Bosh::Helpers::S3Stemcell.new('vsphere', 'basic').download_latest
            Rake::Task['spec:system:vsphere:micro'].invoke
          ensure
            rm_f(Dir.glob('*bosh-stemcell-*.tgz'))
          end
        end
      end
    end
  end
end
