module Bosh::Director::Models
  class CompiledPackage < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :package

    # Creates a 'unique' key to use in the global package cache
    def self.create_cache_key(package, transitive_dependencies, stemcell_sha1)
      dependency_fingerprints = transitive_dependencies.to_a.sort_by(&:name).map {|p| p.fingerprint }
      hash_input = ([package.fingerprint, stemcell_sha1]+dependency_fingerprints).join('')
      Digest::SHA1.hexdigest(hash_input)
    end

    # Marks job template model as being used by release version
    # @param string stemcell os & version, e.g. 'ubuntu_trusty/3146.1'
    # @return hash, e.g. { stemcell_os: 'ubuntu_trusty', stemcell_version: '3146.1' }
    def self.split_stemcell_os_and_version(name)
      values = name.split('/', 2)

      unless 2 == values.length
        raise "Expected value to be in the format of \"{os_name}/{stemcell_version}\", but given \"#{name}\""
      end

      return { os: values[0], version: values[1] }
    end

    def validate
      validates_presence [:package_id, :stemcell_os, :stemcell_version, :sha1, :blobstore_id, :dependency_key]
      validates_unique [:package_id, :stemcell_os, :stemcell_version, :dependency_key]
      validates_unique [:package_id, :stemcell_os, :stemcell_version, :build]
    end

    def before_save
      self.dependency_key_sha1 = Digest::SHA1.hexdigest(self.dependency_key)

      super
    end

    def name
      package.name
    end

    def version
      package.version
    end

    def self.generate_build_number(package_model, stemcell_os, stemcell_version)
      attrs = {
        :package_id => package_model.id,
        :stemcell_os => stemcell_os,
        :stemcell_version => stemcell_version,
      }

      filter(attrs).max(:build).to_i + 1
    end
  end
end
