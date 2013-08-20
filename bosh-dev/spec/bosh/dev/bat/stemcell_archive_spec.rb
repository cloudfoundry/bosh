require 'spec_helper'
require 'bosh/dev/bat/stemcell_archive'

module Bosh::Dev::Bat
  describe StemcellArchive do
    subject do
      StemcellArchive.new(spec_asset('fake-stemcell.tgz'))
    end

    its(:version) { should eq('714') }
  end
end
