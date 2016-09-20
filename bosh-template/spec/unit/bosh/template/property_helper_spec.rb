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

      context '#set_property' do
        it 'should update the hash @ path with provided value' do
          dst = {}
          name = 'foo'
          value = 'bar'
          @helper.set_property(dst, name, value)
          expect(dst['foo']).to eq('bar')
        end

        it 'should update the nested hash @ dot separated path with provided value' do
          dst = {}
          name = 'foo.smurf.color'
          value = 'green'
          @helper.set_property(dst, name, value)
          expect(dst['foo']['smurf']['color']).to eq('green')
        end

      end

      context '#validate_properties_format' do
        context 'when deployment manifest properties are valid' do

          let(:props) do
            {
              'foo' => {
                'bar' => 'omg',
              }
            }
          end

          it 'doesnt raise error' do
              @helper.validate_properties_format(props, 'foo.bar')
          end
        end

        context 'when deployment manifest properties are  NOT valid' do
          let(:props) do
            {
              'foo' => {
                'yarb' => 'i am incorrect'
              }
            }
          end

          it 'raises an Bosh::Template::InvalidPropertyType error' do
            key = 'foo.yarb.pow'

            expect{
              @helper.validate_properties_format(props, key)
            }.to raise_error(Bosh::Template::InvalidPropertyType, "Property 'foo.yarb.pow' expects a hash, but received 'String'")
          end

          context 'when the properties variable is not a hash' do
            it 'raises an Bosh::Template::InvalidPropertyType if the properties is not a hash' do
              expect{
                @helper.validate_properties_format(false, 'a')
              }.to raise_error(Bosh::Template::InvalidPropertyType, "Property 'a' expects a hash, but received 'FalseClass'")
            end
          end
        end
      end
    end
  end
end
