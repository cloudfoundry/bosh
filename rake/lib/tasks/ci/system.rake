require_relative '../../helpers/do_not_add_to_me'

namespace :ci do
  namespace :system do
    include Bosh::Helpers::DoNotAddToMe

    namespace :vsphere do
      task :micro do
        cd(ENV['WORKSPACE']) do
          begin
            download_latest_stemcell('vsphere', 'micro')
            download_latest_stemcell('vsphere', 'basic')
            Rake::Task['spec:system:vsphere:micro'].invoke
          ensure
            rm_f(Dir.glob('*bosh-stemcell-*.tgz'))
          end
        end
      end
    end
  end
end
