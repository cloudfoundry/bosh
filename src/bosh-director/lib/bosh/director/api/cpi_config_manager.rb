module Bosh
  module Director
    module Api
      class CpiConfigManager
        def update(cpi_config_yaml)
          cpi_config = Bosh::Director::Models::CpiConfig.new(
              properties: cpi_config_yaml
          )
          validate_manifest!(cpi_config)
          cpi_config.save
        end

        def list(limit)
          Bosh::Director::Models::CpiConfig.order(Sequel.desc(:id)).limit(limit).to_a
        end

        def latest
          list(1).first
        end

        def find_by_id(id)
          Bosh::Director::Models::CpiConfig.find(id: id)
        end

        private

        def validate_manifest!(cpi_config)
          cpi_manifest = cpi_config.manifest
          Bosh::Director::CpiConfig::CpiManifestParser.new.parse(cpi_manifest)
        end
      end
    end
  end
end
