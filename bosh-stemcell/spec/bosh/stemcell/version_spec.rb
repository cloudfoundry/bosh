require 'spec_helper'
require 'bosh/stemcell/version'

module Bosh::Stemcell
  describe VERSION do
    let(:bosh_version_file) do
      File.expand_path('../../../../BOSH_VERSION', File.dirname(__FILE__))
    end

    it { should eq(File.read(bosh_version_file).strip) }
  end
end
