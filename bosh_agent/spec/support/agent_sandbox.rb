require 'fileutils'
require 'tmpdir'
require 'tempfile'

module Bosh::Agent
  module Spec
    class AgentSandbox
      def initialize(id, mbus, smtp_port, level=nil)
        @base_dir = Dir.mktmpdir
        @id = id
        @mbus = mbus
        @smtp_port = smtp_port
        @logfile = Tempfile.new('agent-log')
        @level = level
      end

      def run
        FileUtils.mkdir_p(File.join(base_dir, 'bosh'))
        write_settings

        cmd = %W(bosh_agent -h 1 -b #{base_dir} -l ERROR -t #{smtp_port} -I dummy)
        cmd += %W(-l #{level}) if level
        $stderr.puts "starting agent: #{cmd.join(' ')}"
        @pid = Process.spawn(*cmd, out: logfile.path, err: logfile.path)
      end

      def stop
        if pid
          $stderr.puts 'stopping agent'

          Process.kill(:TERM, pid)
          Process.waitpid(pid)
        end
        FileUtils.rm_rf(base_dir)
      end

      def agent_logfile
        logfile.path
      end

      private
      attr_reader :base_dir, :id, :mbus, :smtp_port, :pid, :level, :logfile

      def write_settings
        settings = {
          agent_id: id,
          blobstore: {
            provider: 'simple',
            options: {},
          },
          ntp: [],
          disks: {
            persistent: {},
          },
          mbus: mbus,
        }
        File.write(File.join(base_dir, 'bosh', 'settings.json'), JSON.generate(settings))
      end
    end
  end
end
