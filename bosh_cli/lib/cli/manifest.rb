module Bosh::Cli
  class Manifest
    attr_reader :hash

    def initialize(deployment_file, director)
      @deployment_file = deployment_file
      @director = director
    end

    def name
      @hash['name']
    end

    def load
      unless File.exists?(@deployment_file)
        err("Cannot find deployment manifest in '#{@deployment_file}'")
      end

      @hash = load_yaml_file(@deployment_file)
    end

    def validate(options={})
      if @hash['name'].blank?
        err('Deployment name not found in the deployment manifest')
      end

      if @hash['target']
        err(MANIFEST_TARGET_UPGRADE_NOTICE)
      end

      if options[:resolve_properties]
        compiler = DeploymentManifestCompiler.new(Psych.dump(@hash))
        properties = {}

        begin
          say('Getting deployment properties from director...')
          properties = @director.list_properties(name)
        rescue Bosh::Cli::DirectorError
          say('Unable to get properties list from director, ' +
              'trying without it...')
        end

        compiler.properties = properties.inject({}) do |hash, property|
          hash[property['name']] = property['value']
          hash
        end

        @hash = Psych.load(compiler.result)
      end

      if name.blank? || @hash['director_uuid'].blank?
        err("Invalid manifest '#{File.basename(@deployment_file)}': " +
            'name and director UUID are required')
      end

      if @director.uuid != @hash['director_uuid']
        err("Target director UUID doesn't match UUID from deployment manifest")
      end

      if @hash['release'].blank? && @hash['releases'].blank?
        err("Deployment manifest doesn't have release information: '" +
            "please add 'release' or 'releases' section")
      end

      report_manifest_warnings

      @hash
    end

    def yaml
      Psych.dump(@hash)
    end

    # @param [Hash] manifest Deployment manifest (will be modified)
    # @return [void]
    def resolve_stemcell_aliases
      return if @hash['resource_pools'].nil?

      @hash['resource_pools'].each do |rp|
        stemcell = rp['stemcell']
        unless stemcell.is_a?(Hash)
          err('Invalid stemcell spec in the deployment manifest')
        end
        if stemcell['version'] == 'latest'
          latest_version = latest_stemcells[stemcell['name']]
        elsif stemcell['version'] =~ /\.latest$/
          prefix = /^(.+)\.latest$/.match(stemcell['version'])[1]
          latest_version = latest_stemcells(prefix)[stemcell['name']]
        else
          latest_version = stemcell['version']
        end

        if latest_version.nil?
          err("Unable to resolve stemcell '#{stemcell['name']}' for version '#{stemcell['version']}'.")
        end

        stemcell['version'] = latest_version
      end
    end

    private

    def director_stemcells
      @_director_stemcells ||= @director.list_stemcells
    end

    # @return String[String]
    def latest_stemcells(prefix = nil)
      stemcells = director_stemcells.inject({}) do |hash, stemcell|
        unless stemcell.is_a?(Hash) && stemcell['name'] && stemcell['version']
          err('Invalid director stemcell list format')
        end
        hash[stemcell['name']] ||= []
        hash[stemcell['name']] << stemcell['version']
        hash
      end

      unless prefix.nil?
        stemcells.each do | name, versions |
          stemcells[name] = versions.select do | version |
            version.match(/^#{prefix}[\.\-$]/)
          end
        end
      end

      stemcells.inject({}) do |hash, (name, versions)|
        version = Bosh::Common::Version::StemcellVersionList.parse(versions).latest

        unless version.nil?
          hash[name] = version.to_s
        end

        hash
      end
    end

    public

    # @param [Hash] manifest Deployment manifest (will be modified)
    # @return [void]
    def resolve_release_aliases
      releases = @hash['releases'] || [@hash['release']]

      releases.each do |release|
        if release['version'] == 'latest'
          resolved_version = latest_release_versions[release['name']]
        elsif release['version'] =~ /\.latest$/
          director_release = director_releases.detect { |director_release| director_release['name'] == release['name'] }

          if director_release
            prefix = /^(.+)\.latest$/.match(release['version'])[1]

            resolved_version = latest_release_versions_for_release(director_release, prefix)
          end
        else
          resolved_version = release['version']
        end

        unless resolved_version
          err("Unable to resolve release '#{release['name']}' for version '#{release['version']}'.")
        end

        release['version'] = resolved_version
      end
    end

    private

    def latest_release_versions_for_release(release, prefix = nil)
      versions = release['versions'] || release['release_versions'].map { |release_version| release_version['version'] }

      unless prefix.nil?
        versions = versions.select { |release_version| release_version.match(/^#{prefix}[\.\-$]/) }
      end

      if versions.length == 0
        return nil
      end

      parsed_versions = versions.map do |version|
        {
          original: version,
          parsed: Bosh::Common::Version::ReleaseVersion.parse(version)
        }
      end
      latest_version = parsed_versions.sort_by { |v| v[:parsed] }.last[:original]
      return latest_version.to_s
    end

    def director_releases
      @_director_releases ||= begin
        @director.list_releases
      end
    end

    public

    def latest_release_versions
      @_latest_release_versions ||= begin
        director_releases.inject({}) do |hash, release|
          hash[release['name']] = latest_release_versions_for_release(release)
          hash
        end
      end
    end

    MANIFEST_TARGET_UPGRADE_NOTICE =
      <<-EOS.gsub(/^\s*/, '').gsub(/\n$/, '')
        Please upgrade your deployment manifest to use director UUID instead
        of target. Just replace 'target' key with 'director_uuid' key in your
        manifest. You can get your director UUID by targeting your director
        with 'bosh target' and running 'bosh status' command afterwards.
      EOS

    def report_manifest_warnings
      ManifestWarnings.new(@hash).report
    end
  end
end
