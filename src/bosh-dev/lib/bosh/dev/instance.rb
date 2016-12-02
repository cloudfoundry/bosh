require 'rake'

module Bosh
  module Dev
    class Instance
      include Rake::FileUtilsExt

      attr_reader :name, :gw_user, :gw_host

      def initialize(options)
        @name = options.fetch(:instance_name)
        @gw_user = options.fetch(:gw_user)
        @gw_host = options.fetch(:gw_host)
      end

      def run(command)
        sh %{ssh -A #{gw_user}@#{gw_host} 'ssh #{gw_user}@#{ip} -o StrictHostKeyChecking=no "echo c1oudc0w | sudo -S #{command}"'}
      end

      private

      def ip
        @ip ||= `bosh vms | grep #{name} | cut -d "|" -f 5 | cut -d "," -f 1`.strip
      end
    end
  end
end
