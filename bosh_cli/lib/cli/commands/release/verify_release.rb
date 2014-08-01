module Bosh::Cli::Command
  module Release
    class VerifyRelease < Base

      # bosh verify release
      usage 'verify release'
      desc 'Verify release'
      def verify(tarball_path)
        tarball = Bosh::Cli::ReleaseTarball.new(tarball_path)

        nl
        say('Verifying release...')
        tarball.validate
        nl

        if tarball.valid?
          say("`#{tarball_path}' is a valid release".make_green)
        else
          say('Validation errors:'.make_red)
          tarball.errors.each do |error|
            say("- #{error}")
          end
          err("`#{tarball_path}' is not a valid release".make_red)
        end
      end
    end
  end
end
