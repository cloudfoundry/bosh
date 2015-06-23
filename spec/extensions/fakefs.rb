require 'fakefs/version'
require 'fakefs/safe'

unless FakeFS::Version.to_s == '0.6.7'
  raise "Check that FakeFS #{FakeFS::Version} still needs to be patched"
end

module Extensions
  module FakeFS
    module Kernel
      # FakeFS makes `Kernel.open` public, and leaves it public when restoring
      # things via `.unhijack!`. This causes failures in subsequent tests.
      # So, we patch `.unhijack!` to ensure that `Kernel.open` is once again
      # made private.
      def self.unhijack!
        super
        ::Kernel.send(:private, :open)
      end
    end
  end
end

FakeFS::Kernel.send(:include, Extensions::FakeFS::Kernel)
