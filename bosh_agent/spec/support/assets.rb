module Bosh::Agent
  module Spec
    module Assets
      def asset(filename)
        File.expand_path(File.join('../assets', filename), File.dirname(__FILE__))
      end

      def read_asset(filename)
        File.open(asset(filename)).read
      end

      def dummy_package_data
        read_asset('dummy.package')
      end

      def failing_package_data
        read_asset('failing.package')
      end

      def dummy_job_data
        read_asset('job.tgz')
      end
    end
  end
end
