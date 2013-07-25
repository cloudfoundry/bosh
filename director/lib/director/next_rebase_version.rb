module Bosh::Director
  class NextRebaseVersion
    def initialize(existing_versions)
      @existing_versions = existing_versions
    end

    def calculate(current_version)
      current_version = Bosh::Common::VersionNumber.new(current_version)
      versions = @existing_versions.map { |item| Bosh::Common::VersionNumber.new(item.version) }

      return current_version.to_s if current_version.final?

      latest = versions.select { |version|
        version.major == current_version.major
      }.max

      latest ? latest.next_minor.dev.to_s : "#{current_version.major}.1-dev"
    end
  end
end