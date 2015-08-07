# #!/usr/bin/env ruby

class OptionallyRunWithBundler
  def self.run(env)
    if env['BOSH_USE_BUNDLER']
      gemfile_path = File.join(File.dirname(__FILE__), 'run_bosh_with_bundler.Gemfile')

      if File.exists?(gemfile_path)
        rubyopt = [env['RUBYOPT']].compact

        if rubyopt.empty? || rubyopt.first !~ /-rbundler\/setup/
          rubyopt.unshift('-rbundler/setup')

          env['BUNDLE_GEMFILE'] = gemfile_path
          env['RUBYOPT'] = rubyopt.join(' ')

          kernel_exec_current_command
        end
      else
        require "fileutils"
        FileUtils.mkdir_p(File.dirname(gemfile_path))
        File.write(gemfile_path, "gem 'bosh_cli'")

        print "\nOptimizing gem configuration...\n\n"

        env['BUNDLE_GEMFILE'] = gemfile_path

        require 'bundler/setup'
      end
    end
  end

  def self.kernel_exec_current_command
    Kernel.exec($0, *ARGV)
  end
end
