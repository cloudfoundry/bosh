module Bosh
  module Cli

    class Runner

      def self.run(cmd, *args)
        new(cmd, *args).run
      end

      def initialize(cmd, *args)
        @cmd  = cmd
        @args = args
      end

      def run
        method   = find_cmd_implementation
        expected = method.arity

        if expected >= 0 && @args.size != expected
          raise ArgumentError, "wrong number of arguments for #{self.class.name}##{method.name} (#{@args.size} for #{expected})"
        end

        method.call(*@args)
      end

      private

      def find_cmd_implementation
        begin
          self.method(@cmd)
        rescue NameError
          raise UnknownCommand, "unknown command '%s'" % [ @cmd ]
        end
      end
      
    end
    
  end
end
