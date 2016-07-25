module Bosh::Director
  module CpiConfig
    class CpiManifestParser
      include ValidationHelper

      def parse(cpi_manifest)
        ParsedCpiConfig.new(parse_cpis(cpi_manifest))
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

      # TODO: DRY up (exists also in cloud manifest parser)
      def detect_duplicates(collection, &iteratee)
        transformed_elements = Set.new
        duplicated_elements = Set.new
        collection.each do |element|
          transformed = iteratee.call(element)

          if transformed_elements.include?(transformed)
            duplicated_elements << element
          else
            transformed_elements << transformed
          end
        end

        duplicated_elements
      end
    end
  end
end
