
require 'posix/spawn'
require 'yaml'

require 'micro/cache'

module VCAP
  module Micro

    # This utility class is specifically for taking a Micro instance installed
    # by Bosh and cleaning it up just enough so we can export with ovftool a
    # bootable VMX.
    #
    # We will abandon this approach at some point and replace it with one
    # using vmbuilder, which only needs the compiled blobs from the blobstore
    # to work. The benefit of that is that we don't have to do all the cleanup
    # we would have to do with the BoshPrepare approach.
    class BoshPrepare

      def run
        delete_agent_runit_service
        reset_hostname
        reset_etc_host
        copy_micro_to_rootfs
        setup_micro_tty
        prune_apply_spec
        cache_blobs
        prune_files
      end

      def delete_agent_runit_service
        child = POSIX::Spawn::Child.new('sv', 'stop', 'agent')
        unless child.status.exitstatus == 0
          puts 'failed to stop agent'
        end
        FileUtils.rm_rf('/etc/sv/agent')
      end

      def reset_hostname
        File.open('/etc/hostname', 'w') { |f| f.puts("cfmicro") }
      end

      def reset_etc_host
        File.open('/etc/hosts', 'w') { |f| f.puts("127.0.0.1 localhost cfmicro") }
      end

      def copy_micro_to_rootfs
        FileUtils.mkdir('/var/vcap/micro')
        `cp -r /var/vcap/packages/micro/* /var/vcap/micro`
      end

      def setup_micro_tty
        File.open('/etc/init/tty1.conf', 'w') do |f|
          f.puts("start on stopped rc RUNLEVEL=[2345]")
          f.puts("stop on runlevel [!2345]\n")
          f.puts("respawn")
          f.puts("exec /sbin/getty exec /sbin/getty -n -i -l /var/vcap/bin/microconsole -8 38400 tty1 -8 38400 tty1")
        end
      end

      def prune_apply_spec
        state = YAML.load_file('/var/vcap/bosh/state.yml')
        %w{resource_pool networks }.each { |key| state.delete(key )}

        properties = state['properties']

        properties['cc']['token'] = secret(64)
        properties['cc']['password'] = secret(64)
        properties['mysql_node']['password'] = secret(8)
        properties['nats']['password'] = secret(8)
        properties['ccdb']['password'] = secret(8)

        state['properties'] = properties

        File.open('/var/vcap/micro/apply_spec.yml', 'w') { |f| f.write(YAML.dump(state)) }
      end

      def cache_blobs
        spec_file = '/var/vcap/micro/apply_spec.yml'
        settings = '/var/vcap/bosh/settings.json'

        cache = VCAP::Micro::Cache.new(spec_file, '/var/vcap/data/cache', settings)
        cache.setup
        cache.download
      end


      def prune_files
        %w{
          /var/vcap/bosh/settings.json
        }.each do |path|
          FileUtils.rm(path)
        end
      end

      def secret(n)
        OpenSSL::Random.random_bytes(n).unpack("H*")[0]
      end

    end
  end
end

if __FILE__ == $0
  VCAP::Micro::BoshPrepare.new.run
end
