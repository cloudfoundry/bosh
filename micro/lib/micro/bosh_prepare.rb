
require 'posix/spawn'
require 'yaml'

require 'micro/cache'
require 'micro/settings'

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
        stop_micro_job
        delete_agent_runit_service
        reset_hostname
        reset_etc_host
        copy_micro_to_rootfs
        setup_micro_tty
        prune_apply_spec
        cache_blobs
        prune_files
      end

      def stop_micro_job
        # Redo this with the monit gem
        `monit -g vcap stop`
      end

      def delete_agent_runit_service
        child = POSIX::Spawn::Child.new('sv', 'stop', 'agent')
        unless child.status.exitstatus == 0
          puts 'failed to stop agent'
        end
        FileUtils.rm_rf('/etc/sv/agent')
      end

      def reset_hostname
        File.open('/etc/hostname', 'w') { |f| f.puts("micro") }
      end

      def reset_etc_host
        File.open('/etc/hosts', 'w') { |f| f.puts("127.0.0.1 localhost micro") }
      end

      def copy_micro_to_rootfs
        FileUtils.mkdir('/var/vcap/micro')
        `cp -r /var/vcap/packages/micro/* /var/vcap/micro`
        `cp -r /var/vcap/packages/micro/.bundle /var/vcap/micro/.bundle`
      end

      def setup_micro_tty
        File.open('/etc/init/tty1.conf', 'w') do |f|
          f.puts("start on stopped rc RUNLEVEL=[2345]")
          f.puts("stop on runlevel [!2345]\n")
          f.puts("respawn")

          # TODO: Ubuntu does a double exec here - figure out if it's needed
          # (see /etc/init/tty2.conf on any Lucid system)
          f.puts("exec /sbin/getty -n -i -l /var/vcap/micro/bin/microconsole -8 38400 tty1 -8 38400 tty1")
        end
      end

      def prune_apply_spec
        state = YAML.load_file('/var/vcap/bosh/state.yml')
        %w{resource_pool networks }.each { |key| state.delete(key )}

        properties = state['properties']
        state['properties'] = VCAP::Micro::Settings.randomize_passwords(properties)

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
          /var/vcap/jobs
          /var/vcap/packages
          /var/vcap/sys/run
          /var/vcap/sys/dea
          /var/vcap/data/cloudcontroller
          /var/vcap/data/jobs
          /var/vcap/data/log
          /var/vcap/data/packages
          /var/vcap/store/mysql
          /var/vcap/store/mysql_node.db
          /var/vcap/store/redis
          /var/vcap/bosh/src
          /etc/udev/rules.d/70-persistent-net.rules
        }.each do |path|
          FileUtils.rm_rf(path)
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
