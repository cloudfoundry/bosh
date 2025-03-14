module Bosh::Director::Jobs
  module Helpers
    class CompiledPackagesToDeletePicker
      def self.pick(soon_to_delete_stemcells)
        deletable_stemcell_ids = soon_to_delete_stemcells.map do |stemcell|
          stemcell['id']
        end

        Bosh::Director::Models::CompiledPackage.all.select do |cp|
          Bosh::Director::Models::Stemcell.where(operating_system: cp.stemcell_os).find do |stemcell|
            Bosh::Version::StemcellVersion.match(cp.stemcell_version, stemcell.version) &&
              !deletable_stemcell_ids.include?(stemcell.id)
          end.nil?
        end
      end
    end
  end
end
