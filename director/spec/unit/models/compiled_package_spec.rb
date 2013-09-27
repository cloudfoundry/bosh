require 'spec_helper'

module Bosh::Director::Models
  describe CompiledPackage do
    describe '.generate_build_number' do
      it 'returns 1 if no compiled packages for package and stemcell' do
        package = Package.make
        stemcell = Stemcell.make

        CompiledPackage.generate_build_number(package, stemcell).should == 1
      end
      it 'returns 2 if only one compiled package exists for package and stemcell' do
        package = Package.make
        stemcell = Stemcell.make
        CompiledPackage.make(package: package, stemcell: stemcell, build: 1)

        CompiledPackage.generate_build_number(package, stemcell).should == 2
      end

      it 'will return 1 for new, unique combinations of packages and stemcells' do
        5.times do
          package = Package.make
          stemcell = Stemcell.make

          CompiledPackage.generate_build_number(package, stemcell).should == 1
        end
      end
    end
  end
end
