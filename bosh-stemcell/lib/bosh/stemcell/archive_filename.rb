require 'forwardable'

module Bosh::Stemcell
  class ArchiveFilename
    extend Forwardable

    def initialize(version, definition, base_name)
      @version = version
      @definition = definition
      @base_name = base_name
    end

    def to_s
      stemcell_filename_parts = [
        name,
        version,
        definition.stemcell_name
      ]
      "#{stemcell_filename_parts.join('-')}.tgz"
    end

    private

    def name
      mod_name = definition.light? ? "light-#{base_name}" : base_name
      if (RbConfig::CONFIG['host_cpu'] == "powerpc64le") 
        "#{mod_name}-ppc64" 
      else
        mod_name
      end
    end

    attr_reader(
      :base_name,
      :version,
      :definition,
    )
  end
end
