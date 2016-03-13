require 'spec_helper'
require 'bosh/template/property_helper'
require 'bosh/template/invalid_property_type'

module Bosh
  module Template
    describe PropertyHelper do
      before do
        @helper = Object.new
        @helper.extend(PropertyHelper)
      end

      it 'can copy named property from one collection to another' do
        dst = {}
        src = {'foo' => {'bar' => 'baz', 'secret' => 'zazzle'}}

        @helper.copy_property(dst, src, 'foo.bar')
        expect(dst).to eq({'foo' => {'bar' => 'baz'}})

        @helper.copy_property(dst, src, 'no.such.prop', 'default')
        expect(dst).to eq({
          'foo' => {'bar' => 'baz'},
          'no' => {
            'such' => {'prop' => 'default'}
          }
        })
      end

      it 'should return the default value if the value not found in src' do
        dst = {}
        src = {}
        @helper.copy_property(dst, src, 'foo.bar', 'foobar')
        expect(dst).to eq({'foo' => {'bar' => 'foobar'}})
      end

      context 'when src parameter is not a hash' do
        it 'should raise a useful exception' do
          dst = {}
          src = false
          expect {
            @helper.copy_property(dst, src, 'foo.bar', 'foobar')
          }.to raise_error(InvalidPropertyType, "Property 'foo.bar' expects a hash, but received '#{src.class}'")
        end
      end

      it "should return the 'false' value when parsing a boolean false value" do
        dst = {}
        src = {'foo' => {'bar' => false}}
        @helper.copy_property(dst, src, 'foo.bar', true)
        expect(dst).to eq({'foo' => {'bar' => false}})
      end

      it 'should get a nil when value not found in src and no default value specified ' do
        dst = {}
        src = {}
        @helper.copy_property(dst, src, 'foo.bar')
        expect(dst).to eq({'foo' => {'bar' => nil}})
      end

      it 'can lookup the property in a Hash using dot-syntax' do
        properties = {
          'foo' => {'bar' => 'baz'},
          'router' => {'token' => 'foo'}
        }

        expect(@helper.lookup_property(properties, 'foo.bar')).to eq('baz')
        expect(@helper.lookup_property(properties, 'router')).to eq({'token' => 'foo'})
        expect(@helper.lookup_property(properties, 'no.prop')).to be_nil
      end
    end
  end
end
