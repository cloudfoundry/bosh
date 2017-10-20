module Bosh::Director
  module CpiConfig
    class CpiManifestParser
      include ValidationHelper
      include DuplicateDetector

      def parse(cpi_manifest)
        ParsedCpiConfig.new(parse_cpis(cpi_manifest))
      end

      def merge_configs(cpi_configs)
        result_hash = {'cpis' => []}
        cpi_configs.each do |cpi_config|
          result_hash['cpis'] += safe_property(cpi_config, 'cpis', :class => Array)
        end
        result_hash
      end

      private

      def parse_cpis(cpi_manifest)
        parsed_cpis = safe_property(cpi_manifest, 'cpis', :class => Array).map do |cpi|
          CpiConfig::Cpi.parse(cpi)
        end

        duplicates = detect_duplicates(parsed_cpis) { |cpi| cpi.name }
        unless duplicates.empty?
          raise CpiDuplicateName, "Duplicate cpi name '#{duplicates.first.name}'"
        end

        parsed_cpis
      end
    end
  end
end
