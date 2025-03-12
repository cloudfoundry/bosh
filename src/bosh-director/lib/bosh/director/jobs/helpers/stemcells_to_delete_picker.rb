module Bosh::Director::Jobs
  module Helpers
    class StemcellsToDeletePicker
      def initialize(stemcell_manager)
        @stemcell_manager = stemcell_manager
      end

      def pick(stemcells_to_keep)
        unused_stemcell_names_and_versions = @stemcell_manager
                                             .find_all_stemcells
                                             .select { |stemcell| stemcell['deployments'].empty? }

        unused_stemcells_grouped_by_name = unused_stemcell_names_and_versions.inject({}) do |h, stemcell|
          h[stemcell['name']] ||= []
          h[stemcell['name']] << stemcell
          h
        end

        stemcells_to_versions_to_delete = unused_stemcells_grouped_by_name.each_pair do |_, versions|
          versions.sort! do |sc1, sc2|
            Bosh::Version::StemcellVersion.parse(sc1['version']) <=> Bosh::Version::StemcellVersion.parse(sc2['version'])
          end
          versions.pop(stemcells_to_keep)
        end

        stemcells_to_versions_to_delete.values.flatten
      end
    end
  end
end
