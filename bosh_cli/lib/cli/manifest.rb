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
        err("Cannot find deployment manifest in `#{@deployment_file}'")
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
        compiler = DeploymentManifestCompiler.new(File.read(@deployment_file))
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
        err("Invalid manifest `#{File.basename(@deployment_file)}': " +
            'name and director UUID are required')
      end

      if @director.uuid != @hash['director_uuid']
        err("Target director UUID doesn't match UUID from deployment manifest")
      end

      if @hash['release'].blank? && @hash['releases'].blank?
        err("Deployment manifest doesn't have release information: '" +
            "please add 'release' or 'releases' section")
      end

      resolve_release_aliases
      resolve_stemcell_aliases

      report_manifest_warnings

      @hash
    end

    def yaml
      @yaml ||= Psych.dump(@hash)
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
          if latest_version.nil?
            err("Latest version for stemcell `#{stemcell['name']}' is unknown")
          end
          # Avoiding {Float,Fixnum} -> String noise in diff
          if latest_version.to_s == latest_version.to_f.to_s
            latest_version = latest_version.to_f
          elsif latest_version.to_s == latest_version.to_i.to_s
            latest_version = latest_version.to_i
          end
          stemcell['version'] = latest_version
        end
      end
    end

    # @return [Array]
    def latest_stemcells
      @_latest_stemcells ||= begin
        stemcells = @director.list_stemcells.inject({}) do |hash, stemcell|
          unless stemcell.is_a?(Hash) && stemcell['name'] && stemcell['version']
            err('Invalid director stemcell list format')
          end
          hash[stemcell['name']] ||= []
          hash[stemcell['name']] << stemcell['version']
          hash
        end

        stemcells.inject({}) do |hash, (name, versions)|
          hash[name] = Bosh::Common::Version::StemcellVersionList.parse(versions).latest.to_s
          hash
        end
      end
    end

    # @param [Hash] manifest Deployment manifest (will be modified)
    # @return [void]
    def resolve_release_aliases
      releases = @hash['releases'] || [@hash['release']]

      releases.each do |release|
        if release['version'] == 'latest'
          latest_release_version = latest_release_versions[release['name']]
          unless latest_release_version
            err("Release '#{release['name']}' not found on director. Unable to resolve 'latest' alias in manifest.")
          end
          release['version'] = latest_release_version
        end

        if release['version'].to_i.to_s == release['version']
          release['version'] = release['version'].to_i
        end
      end
    end

    def latest_release_versions
      @_latest_release_versions ||= begin
        @director.list_releases.inject({}) do |hash, release|
          name = release['name']
          versions = release['versions'] || release['release_versions'].map { |release_version| release_version['version'] }
          parsed_versions = versions.map do |version|
            {
              original: version,
              parsed: Bosh::Common::Version::ReleaseVersion.parse(version)
            }
          end
          latest_version = parsed_versions.sort_by { |v| v[:parsed] }.last[:original]
          hash[name] = latest_version.to_s
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
