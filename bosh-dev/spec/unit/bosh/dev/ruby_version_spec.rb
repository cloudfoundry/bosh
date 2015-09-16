require 'rspec'
require 'bosh/dev/ruby_version'

module Bosh::Dev
  describe RubyVersion do
    describe ".legacy_version" do
      it "is the 1.9 Ruby version we still support for BOSH CLI" do
        expect(RubyVersion.legacy_version).to eq('1.9.3')
      end
    end

    describe ".release_version" do
      it "is the 2.x Ruby version defined by the BOSH release" do
        expect(RubyVersion.release_version).to eq('2.1.7')
      end
    end

    describe ".supported" do
      it "includes the running Ruby version" do
        supported = RubyVersion.supported
        expect(supported).to include(RUBY_VERSION),
        "expected development Ruby version, #{RUBY_VERSION}, to be one of #{supported.join(' ')}"
      end
    end
  end
end
