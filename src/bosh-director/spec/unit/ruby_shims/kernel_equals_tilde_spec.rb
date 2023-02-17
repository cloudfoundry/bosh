require 'spec_helper'
require 'ruby_shims/kernel_equals_tilde'

describe 'Kernel =~' do
    it 'preserves pre ruby 3.2 behavior of falling back to nil' do
      expect(Object.new =~ /anything/).to be_nil
    end
end
