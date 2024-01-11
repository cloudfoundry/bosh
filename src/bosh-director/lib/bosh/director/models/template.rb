module Bosh::Director::Models

  # This class models a job, as defined within a Bosh Release.
  #
  # Here “template” is the old Bosh v1 name for “job”.
  class Template < Sequel::Model(Bosh::Director::Config.db)
    many_to_one :release
    many_to_many :release_versions

    def validate
      validates_presence [:release_id, :name, :version, :blobstore_id, :sha1]
      validates_unique [:release_id, :name, :version]
      validates_format VALID_ID, [:name, :version]
    end

    def self.find_or_init_from_release_meta(release:, job_meta:, job_manifest:)
      template = first(
        name: job_meta['name'],
        release_id: release.id,
        fingerprint: job_meta['fingerprint'],
        version: job_meta['version']
      )

      if template
        template.sha1 = job_meta['sha1']
      else
        template = new(
          name: job_meta['name'],
          release_id: release.id,
          fingerprint: job_meta['fingerprint'],
          version: job_meta['version'],
          sha1: job_meta['sha1'],
        )
      end

      template.spec = job_manifest
      template.package_names = parse_package_names(job_manifest)

      template
    end

    def spec
      object_or_nil(self.spec_json) || {}
    end

    def spec=(spec)
      self.spec_json = json_encode(spec)
    end

    def package_names
      object_or_nil(self.package_names_json)
    end

    def package_names=(packages)
      self.package_names_json = json_encode(packages)
    end

    def logs
      spec['logs'] || []
    end

    def properties
      spec['properties'] || {}
    end

    def consumes
      spec['consumes'] || []
    end

    def provides
      spec['provides'] || []
    end

    def runs_as_errand?
      return false if templates == nil

      templates.values.include?('bin/run') ||
        templates.values.include?('bin/run.ps1')
    end

    private

    def templates
      spec['templates'] || {}
    end

    def object_or_nil(value)
      if value == 'null' || value == nil
        nil
      else
        JSON.parse(value)
      end
    end

    def json_encode(value)
      value.nil? ? 'null' : JSON.generate(value)
    end

    def self.parse_package_names(job_manifest)
      if job_manifest['packages'] && !job_manifest['packages'].is_a?(Array)
        raise Bosh::Director::JobInvalidPackageSpec, "Job '#{name}' has invalid package spec format"
      end
      job_manifest['packages'] || []
    end
  end
end
