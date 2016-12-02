module Bosh::Cli::Resources
  class License
    # @param [String] directory base Release directory
    def self.discover(release_base)
      [new(release_base)]
    end

    attr_reader :release_base

    def initialize(release_base)
      @release_base = Pathname.new(release_base)
    end

    def singular_type
      'license'
    end

    def plural_type
      ''
    end

    def name
      'license'
    end

    def files
      Dir[File.join(release_base, "{LICENSE,NOTICE}{,.*}")].map { |entry| [entry, File.basename(entry)] }
    end

    def validate!
      if files.empty?
        raise Bosh::Cli::MissingLicense, "Missing LICENSE or NOTICE in #{release_base.to_s}"
      end
    end

    def format_fingerprint(digest, filename, name, file_mode)
      "%s%s" % [File.basename(filename), digest]
    end

    def additional_fingerprints
      []
    end

    def dependencies
      []
    end

    def run_script(script_name, *args)
      # no-op
    end
  end
end
