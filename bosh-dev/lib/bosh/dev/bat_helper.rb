module Bosh
  module Dev
    class BatHelper
      AWS = 'aws'
      INFRASTRUCTURE = %w[openstack vsphere] << AWS

      attr_reader :workspace_dir
      attr_reader :infrastructure

      def initialize(workspace_dir, infrastructure)
        raise ArgumentError.new("invalid infrastructure: #{infrastructure}") unless INFRASTRUCTURE.include?(infrastructure)

        @workspace_dir = workspace_dir
        @infrastructure = infrastructure
      end

      def light?
        infrastructure == AWS
      end

      def run_rake
        Dir.chdir(workspace_dir) do
          ENV['BAT_INFRASTRUCTURE'] = infrastructure

          begin
            pipeline = Bosh::Dev::Pipeline.new
            pipeline.download_latest_stemcell(infrastructure: infrastructure, name: 'micro-bosh-stemcell', light: light?)
            pipeline.download_latest_stemcell(infrastructure: infrastructure, name: 'bosh-stemcell', light: light?)

            Rake::Task["spec:system:#{infrastructure}:micro"].invoke
          ensure
            cleanup_stemcells
          end
        end
      end

      def cleanup_stemcells
        FileUtils.rm_f(Dir.glob(File.join(workspace_dir, '*bosh-stemcell-*.tgz')))
      end
    end
  end
end