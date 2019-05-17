module Bosh::Director::Jobs
  module Helpers
    class CompiledPackagesToDeletePicker
      def self.pick
        Bosh::Director::Models::CompiledPackage.all.select do |cp|
          Bosh::Director::Models::Stemcell.where(operating_system: cp.stemcell_os).find do |stemcell|
            Bosh::Common::Version::StemcellVersion.match(cp.stemcell_version, stemcell.version)
          end.nil?
        end
      end
    end
  end
end
