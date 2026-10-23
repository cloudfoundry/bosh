require 'spec_helper'

module Bosh::Director
  describe Models do
    describe 'VALID_ID' do
      %w[example example-job example_package 1.2.3 42+dev.6 .hidden ...].each do |identifier|
        it "accepts #{identifier.inspect}" do
          expect(Models::VALID_ID.match?(identifier)).to be(true)
        end
      end

      ['', '.', '..', "valid\n../../etc/file", "../../etc/file\nvalid", "valid\n", "valid\r\n", 'a/b', 'a\\b', 'bad@name'].each do |identifier|
        it "rejects #{identifier.inspect}" do
          expect(Models::VALID_ID.match?(identifier)).to be(false)
        end
      end
    end
  end
end
