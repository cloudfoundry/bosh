require 'spec_helper'

describe VimSdk::VmodlHelper do
  describe :camelize do
    it 'should camelize simple forms' do
      expect(VimSdk::VmodlHelper.camelize('Foo')).to eq('Foo')
      expect(VimSdk::VmodlHelper.camelize('foo')).to eq('Foo')
      expect(VimSdk::VmodlHelper.camelize('foo_bar')).to eq('FooBar')
    end
  end

  describe :underscore do
    it 'should underscore simple forms' do
      expect(VimSdk::VmodlHelper.underscore('test')).to eq('test')
      expect(VimSdk::VmodlHelper.underscore('thisIsAProperty')).to eq('this_is_a_property')
    end

    it 'should underscore exceptional forms' do
      expect(VimSdk::VmodlHelper.underscore('numCPUs')).to eq('num_cpus')
    end
  end

  describe :vmodl_type_to_ruby do
    it 'should convert VMODL type name to ruby' do
      expect(VimSdk::VmodlHelper.vmodl_type_to_ruby('vmodl.query.PropertyCollector.Change.Op')).to eq(
          'Vmodl.Query.PropertyCollector.Change.Op'
      )
    end
  end

  describe :vmodl_property_to_ruby do
    it 'should convert VMODL property name to ruby' do
      expect(VimSdk::VmodlHelper.vmodl_property_to_ruby('testProperty')).to eq('test_property')
    end
  end
end
