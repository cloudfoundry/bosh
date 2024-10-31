module IntegrationSupport
  module CreateReleaseOutputParsers
    def parse_release_tarball_path(create_release_output)
      regex = /^Archive\s+(.*\.tgz)\s*$/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end

    def parse_release_name(create_release_output)
      regex = /^Name\s*(\S*)/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end

    def parse_release_version(create_release_output)
      regex = /^Version\s*(\S*)/
      expect(create_release_output).to match(regex)
      create_release_output.match(regex)[1]
    end
  end
end
