module Bosh::Cli::Command
  module Release
    class ResetRelease < Base

      usage 'reset release'
      desc 'Reset dev release'
      def reset
        check_if_release_dir

        say('Your dev release environment will be completely reset'.make_red)
        if confirmed?
          say('Removing dev_builds index...')
          FileUtils.rm_rf('.dev_builds')
          say('Clearing dev name...')
          release.dev_name = nil
          release.save_config
          say('Removing dev tarballs...')
          FileUtils.rm_rf('dev_releases')

          say('Release has been reset'.make_green)
        else
          say('Canceled')
        end
      end
    end
  end
end
