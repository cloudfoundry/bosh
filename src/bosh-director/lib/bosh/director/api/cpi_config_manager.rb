module Bosh
  module Director
    module Api
      class CpiConfigManager
        def update(cpi_config_yaml)
          cpi_config = Bosh::Director::Models::Config.new(
              type: 'cpi',
              name: 'default',
              content: cpi_config_yaml
          )
          validate_manifest!(cpi_config)
          cpi_config.save
        end

        def list(limit)
          Bosh::Director::Models::Config.where(deleted: false, type: 'cpi', name: 'default').order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        private

        def validate_manifest!(cpi_config)
          cpi_manifest = cpi_config.raw_manifest
          Bosh::Director::CpiConfig::CpiManifestParser.new.parse(cpi_manifest)
        end
      end
    end
  end
end
