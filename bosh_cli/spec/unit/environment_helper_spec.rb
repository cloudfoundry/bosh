require "spec_helper"

describe Bosh::Cli::EnvironmentHelper do
  include Bosh::Cli::EnvironmentHelper

  describe "#tmp_dir" do
    context "when ENV['TMPDIR'] is not set" do

      before(:each) do
        ENV.delete('TMPDIR')
      end

      it "generates a new tmpdir" do
        expect(Bosh::Cli::EnvironmentHelper.tmp_dir).to_not be_nil
      end

      it "sets ENV['TMPDIR'] to newly generated tmpdir" do
        new_tmp_dir = Bosh::Cli::EnvironmentHelper.tmp_dir
        expect(ENV['TMPDIR']).to eq(new_tmp_dir)
      end
    end

    context "when ENV['TMPDIR'] is set" do
      it "uses already set ENV['TMPDIR']" do
        preset_tmp_dir = "/tmp/foo"
        ENV['TMPDIR'] = preset_tmp_dir
        expect(Bosh::Cli::EnvironmentHelper.tmp_dir).to eq(preset_tmp_dir)
      end
    end
  end
end