module Bosh::Cli
  class YamlHelper 
    class << self
      private
      def process_object(o)
        case o
        when @syck_class::Map
          process_map(o)
        when @syck_class::Seq
          process_seq(o)
        when @syck_class::Scalar
        else
          err("Unhandled class #{o.class}, fix yaml duplicate check")
        end
      end

      def process_seq(s)
        s.value.each do |v|
          process_object(v)
        end
      end

      def process_map(m)
        return if m.class != @syck_class::Map
        s = Set.new
        m.value.each_key do  |k|
          raise "Found dup key #{k.value}" if s.include?(k.value)
          s.add(k.value)
        end

        m.value.each_value do |v|
          process_object(v)
        end
      end

      public
      def check_duplicate_keys(path)
        @syck_class = nil
        if RUBY_VERSION =~  /^1\.9\.\d+/
          @syck_class = Syck
        else
          @syck_class = YAML::Syck
        end

        File.open(path) do |f|
          begin
            process_map(YAML.parse(f))
          rescue => e
            raise "Bad yaml file #{path}, " + e.message
          end
        end
      end
    end
  end
end
