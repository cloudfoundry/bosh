module VimSdk
  module Vmodl
    class ManagedObject < DataObject
      @type_info = ManagedType.new("vmodl.ManagedObject", "ManagedObject", nil, VimSdk::BASE_VERSION, [], [])

      class << self

        [:managed_methods].each do |name|
          define_method(name) { @type_info.send(name) }
        end

        def invoke_method(object, managed_method, *args)
          object.__stub__.invoke_method(object, managed_method, args)
        end

        def invoke_property(object, property)
          object.__stub__.invoke_property(object, property)
        end

        def finalize
          build_property_indices

          @type_info.properties.each do |property|
            property.type = VmomiSupport.loaded_type(property.type) if property.type.kind_of?(String)
            self.instance_eval do
              define_method(property.name) do |*args|
                if args.length != 0
                  raise ArgumentError, "wrong number of arguments (#{args.length} for 0)"
                end
                self.class.invoke_property(self, property)
              end
            end
          end

          @type_info.managed_methods.each do |method|
            method.result_type = VmomiSupport.loaded_type(method.result_type) if method.result_type.kind_of?(String)
            method.arguments.each do |argument|
              argument.type = VmomiSupport.loaded_type(argument.type) if argument.type.kind_of?(String)
            end
            self.instance_eval do
              define_method(method.name) do |*args|
                if args.length != method.arguments.length
                  raise ArgumentError, "wrong number of arguments (#{args.length} for #{method.arguments.length})"
                end
                self.class.invoke_method(self, method, *args)
              end
            end
          end
        end
      end

      attr_accessor :__mo_id__
      attr_accessor :__stub__

      def initialize(mo_id, stub = nil)
        @__mo_id__ = mo_id
        @__stub__ = stub
      end

      def to_s
        "<[#{self.class.name}] #{@__mo_id__}>"
      end

      def to_str
        @__mo_id__
      end

      def hash
        __mo_id__.hash
      end

      def eql?(other)
        @__mo_id__ == other.__mo_id__
      end

    end
  end
end