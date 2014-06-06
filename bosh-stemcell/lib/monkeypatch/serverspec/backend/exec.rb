# rubocop:disable all
# => disabling rubocop to preserve original style
require 'serverspec'
require 'serverspec/helper/backend'
require 'pathname'

unless Serverspec::VERSION == '0.15.4'
  raise "Unexpected Serverspec version #{Serverspec::VERSION}"
end

module SpecInfra::Backend
  class Exec
    # ORIGINAL
    # def run_command(cmd, opts={})
    #   cmd = build_command(cmd)
    #   cmd = add_pre_command(cmd)
    #   stdout = run_with_no_ruby_environment do
    #     `#{build_command(cmd)} 2>&1`
    #   end
    #   # In ruby 1.9, it is possible to use Open3.capture3, but not in 1.8
    #   # stdout, stderr, status = Open3.capture3(cmd)
    #
    #   if @example
    #     @example.metadata[:command] = cmd
    #     @example.metadata[:stdout]  = stdout
    #   end
    #
    #   CommandResult.new :stdout => stdout, :exit_status => $?.exitstatus
    # end
    #/ORIGINAL

    def run_command(cmd, opts={})
      cmd = build_command(cmd)
      cmd = add_pre_command(cmd)
      cmd = build_command(cmd)

      if use_chroot?
        chroot_stdout = `#{chroot_cmd(cmd)} 2>&1`

        stdout = get_stdout(chroot_stdout)
        exit_status = get_exit_status(chroot_stdout)
      else
        stdout = run_with_no_ruby_environment { `#{cmd} 2>&1` }
        exit_status = $?.exitstatus
      end
      # In ruby 1.9, it is possible to use Open3.capture3, but not in 1.8
      #stdout, stderr, status = Open3.capture3(cmd)

      if @example
        @example.metadata[:command] = cmd
        @example.metadata[:stdout] = stdout
      end

      CommandResult.new :stdout => stdout, :exit_status => exit_status
    end

    attr_accessor :chroot_dir

    private

    def get_stdout(chroot_stdout)
      chroot_stdout.gsub(/#{exit_code_regexp}/, '')
    end

    def get_exit_status(chroot_stdout)
      chroot_command_exit_status = chroot_stdout.match(/#{exit_code_regexp}/)[1]
      chroot_command_exit_status.to_i
    end

    def use_chroot?
      chroot_dir
    end

    def exit_code_token
      'EXIT_CODE='
    end

    def exit_code_regexp
      "#{exit_code_token}(\\d+)\s*\n"
    end

    def chroot_cmd(cmd)
      #quoting command so $ will not be interpreted by shell
      quoted_cmd = cmd.gsub('$', '\$')
      %Q{
sudo chroot #{chroot_dir} /bin/bash <<CHROOT_CMD
  #{quoted_cmd} 2>&1; echo #{exit_code_token}\\$?
CHROOT_CMD
}
    end
  end
end
