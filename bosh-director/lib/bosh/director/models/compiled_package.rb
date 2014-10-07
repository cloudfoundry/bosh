module Bosh::Director::Models
  class CompiledPackage < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :package
    many_to_one :stemcell

    # Creates a dependency_key from a list of dependencies
    # Input MUST include immediate & transitive dependencies
    def self.create_dependency_key(transitive_dependencies)
      key = transitive_dependencies.to_a.sort_by(&:name).map { |p| [p.name, p.version]}
      Yajl::Encoder.encode(key)
    end

    # Creates a 'unique' key to use in the global package cache
    def self.create_cache_key(package, transitive_dependencies, stemcell)
      dependency_fingerprints = transitive_dependencies.to_a.sort_by(&:name).map {|p| p.fingerprint }
      hash_input = ([package.fingerprint, stemcell.sha1]+dependency_fingerprints).join('')
      Digest::SHA1.hexdigest(hash_input)
    end

    def validate
      validates_presence [:package_id, :stemcell_id, :sha1, :blobstore_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :dependency_key]
      validates_unique [:package_id, :stemcell_id, :build]
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

    def self.generate_build_number(package, stemcell)
      attrs = {
        :package_id => package.id,
        :stemcell_id => stemcell.id
      }

      filter(attrs).max(:build).to_i + 1
    end
  end
end
