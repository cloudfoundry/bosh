module Bosh::Spec
  module CreateReleaseOutputParsers

    def parse_release_manifest_path(create_release_output)
      regex = /^Release manifest: (.*\.yml)$/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end

    def parse_release_tarball_path(create_release_output)
      regex = /^Release tarball \(.*\): (.*\.tgz)$/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end

    def parse_release_name(create_release_output)
      regex = /^Release name: (.*)$/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end

    def parse_release_version(create_release_output)
      regex = /^Release version: (.*)$/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end
  end
end
