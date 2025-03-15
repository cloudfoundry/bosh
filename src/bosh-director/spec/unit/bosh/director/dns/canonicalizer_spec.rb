require 'spec_helper'

module Bosh::Director
  describe Canonicalizer do
    describe '#canonical' do
      it 'should be lowercase' do
        expect(Canonicalizer.canonicalize('HelloWorld')).to eq('helloworld')
        expect(Canonicalizer.canonicalize('HelloWorld', :allow_dots => true)).to eq('helloworld')
      end

      it 'should convert underscores to hyphens' do
        expect(Canonicalizer.canonicalize('hello_world')).to eq('hello-world')
        expect(Canonicalizer.canonicalize('hello_world', :allow_dots => true)).to eq('hello-world')
      end

      it 'should strip any non alpha numeric characters' do
        expect(Canonicalizer.canonicalize('hello$world')).to eq('helloworld')
        expect(Canonicalizer.canonicalize('hello$world', :allow_dots => true)).to eq('helloworld')
      end

      it 'should strip dots based on  allow_dots option' do
        expect(Canonicalizer.canonicalize('hello.world')).to eq('helloworld')
        expect(Canonicalizer.canonicalize('hello.world', :allow_dots => true)).to eq('hello.world')
      end

      it 'should allow string starting with number' do
        expect(Canonicalizer.canonicalize('4helloworld')).to eq('4helloworld')
      end

      it "should reject strings that begin or end with a hyphen" do
        expect {
          Canonicalizer.canonicalize('-helloworld')
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name '-helloworld', cannot start with a hyphen"
        )

        expect {
          Canonicalizer.canonicalize('-helloworld', :allow_dots => true)
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name '-helloworld', cannot start with a hyphen",
        )

        expect {
          Canonicalizer.canonicalize('helloworld-')
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name 'helloworld-', cannot end with a hyphen",
        )

        expect {
          Canonicalizer.canonicalize('helloworld-', :allow_dots => true)
        }.to raise_error(
          DnsInvalidCanonicalName,
          "Invalid DNS canonical name 'helloworld-', cannot end with a hyphen",
        )
      end
    end
  end
end
