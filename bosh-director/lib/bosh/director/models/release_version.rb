module Bosh::Director::Models
  class ReleaseVersion < Sequel::Model(Bosh::Director::Config.db)
    many_to_one  :release
    many_to_many :packages
    many_to_many :templates
    many_to_many :deployments

    def validate
      validates_format VALID_ID, :version
      validates_presence [:release_id, :version]
      validates_unique [:release_id, :version]
    end

    def dependencies(package_name)
      package_by_name(package_name).dependency_set.map do |package_name|
        package_by_name(package_name)
      end
    end

    def package_by_name(package_name)
      packages_by_name.fetch(package_name)
    end

    def package_dependency_key(package_name)
      key = dependencies(package_name).sort { |a, b|
        a.name <=> b.name
      }.map { |p| [p.name, p.version]}

      Yajl::Encoder.encode(key)
    end

    def package_cache_key(package_name, stemcell)
      dependency_fingerprints = dependencies(package_name).sort_by(&:name).map {|p| p.fingerprint }
      hash_input = ([package_by_name(package_name).fingerprint, stemcell.sha1]+dependency_fingerprints).join("")
      Digest::SHA1.hexdigest(hash_input)
    end

    private

    def packages_by_name
      @packages_by_name ||= packages.inject({}) do |cache, package|
        cache.merge(package.name => package)
      end
    end
  end
end
