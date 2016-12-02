module Bosh::Cli::Command
  module Release
    class InitRelease < Base

      # bosh init release
      usage 'init release'
      desc 'Initialize release directory'
      option '--git', 'initialize git repository'
      def init(base = nil)
        if base
          FileUtils.mkdir_p(base)
          Dir.chdir(base)
        end

        err('Release already initialized') if in_release_dir?
        git_init if options[:git]

        %w[config jobs packages src blobs].each do |dir|
          FileUtils.mkdir(dir)
        end

        # Initialize an empty blobs index
        File.open(File.join('config', 'blobs.yml'), 'w') do |f|
          Psych.dump({}, f)
        end

        say('Release directory initialized'.make_green)
      end

      private

      def git_init
        out = %x{git init 2>&1}
        if $? != 0
          say("error running 'git init':\n#{out}")
        else
          Bosh::Cli::SourceControl::GitIgnore.new(@work_dir).update
        end
      rescue Errno::ENOENT
        say("Unable to run 'git init'".make_red)
      end

    end
  end
end
