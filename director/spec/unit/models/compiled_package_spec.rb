require 'spec_helper'

describe Bosh::Director::Models::CompiledPackage do

  def make(attrs = {})
    described_class.make(attrs)
  end

  describe '.generate_build_number' do
    it "returns 1 if no compiled packages for package and stemcell" do
      package = BDM::Package.make
      stemcell = BDM::Stemcell.make

      BDM::CompiledPackage.generate_build_number(package, stemcell).should == 1
    end
    it "returns 2 if only one compiled package exists for package and stemcell" do
      package = BDM::Package.make
      stemcell = BDM::Stemcell.make
      make(package: package, stemcell: stemcell, build: 1)

      BDM::CompiledPackage.generate_build_number(package, stemcell).should == 2
    end

    it 'will return 1 for new, unique combinations of packages and stemcells' do
      5.times do
        package = BDM::Package.make
        stemcell = BDM::Stemcell.make

        BDM::CompiledPackage.generate_build_number(package, stemcell).should == 1
      end
    end
  end
end
