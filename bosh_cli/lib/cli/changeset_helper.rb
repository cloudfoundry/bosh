# encoding: UTF-8

module Bosh::Cli
  class HashChangeset
    class FormatError < StandardError; end

    attr_accessor :values

    def initialize
      @children = {}
      @values   = { :old => nil, :new => nil }
    end

    def [](key)
      @children[key.to_s]
    end

    def keys
      @children.keys
    end

    def []=(key, value)
      @children[key.to_s] = value
    end

    def add_hash(hash, as)
      unless hash.is_a?(Hash)
        raise FormatError, "Trying to add #{hash.class} to a changeset, " +
            "Hash expected"
      end

      self.values[as] = hash

      hash.each_pair do |k, v|
        self[k] ||= HashChangeset.new
        self[k].values[as] = v

        if v.is_a?(Hash)
          self[k].add_hash(v, as)
        end
      end
    end

    def leaf?
      @children.empty?
    end

    def each(&block)
      @children.each_value { |v| yield v }
    end

    def summary(level = 0)
      indent = '  ' * level
      out = []

      @children.each_pair do |k, v|
        if v.state == :mismatch
          out << indent + "#{k} type changed: ".make_yellow +
              "#{v.old.class.to_s} -> #{v.new.class.to_s}"
          out << diff(v.old, v.new, indent + "  ")
        elsif v.leaf?
          case v.state
          when :added
            out << indent + "+ #{k}: ".make_yellow + v.new.to_s
          when :removed
            out << indent + "- #{k}: ".make_red + v.old.to_s
          when :changed
            out << indent + "± #{k}: ".make_yellow
            out << diff(v.old, v.new, indent + "  ")
          end
        else
          child_summary = v.summary(level + 1)

          unless child_summary.empty?
            out << indent + k
            out << child_summary
          end
        end
      end
      out
    end

    def diff(old_value, new_value, indent)
      old_value  = [old_value] unless old_value.kind_of?(Array)
      new_value  = [new_value] unless new_value.kind_of?(Array)

      added   = new_value - old_value
      removed = old_value - new_value

      lines = []

      # Ruby 1.8 has ugly Hash#to_s, hence the normalization

      removed.each do |line|
        line = line.inspect if line.is_a?(Hash)
        lines << "#{indent}- #{line}".make_red
      end

      added.each do |line|
        line = line.inspect if line.is_a?(Hash)
        lines << "#{indent}+ #{line}".make_green
      end

      lines.join("\n")
    end

    def old
      @values[:old]
    end

    def new
      @values[:new]
    end

    def state
      if old.nil? && new.nil?
        :none
      elsif old.nil? && !new.nil?
        :added
      elsif !old.nil? && new.nil?
        :removed
      elsif old.class != new.class && !(boolean?(old) && boolean?(new))
        :mismatch
      elsif old == new
        :same
      else
        :changed
      end
    end

    [:added, :removed, :mismatch, :changed, :same].each do |s|
      define_method("#{s}?".to_sym) do
        state == s
      end
    end

    def boolean?(value)
      value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
    end
  end
end
