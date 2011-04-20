module Bosh::Cli
  class HashChangeset
    class FormatError < StandardError; end

    attr_accessor :values

    def initialize
      @children = {}
      @values   = {:old => nil, :new => nil}
    end

    def [](key)
      @children[key.to_s]
    end

    def []=(key, value)
      @children[key.to_s] = value
    end

    def add_hash(hash, as)
      raise FormatError, "Trying to add #{hash.class} to a changeset, Hash expected" unless hash.is_a?(Hash)

      hash.each_pair do |k, v|
        self[k] ||= HashChangeset.new

        if v.is_a?(Hash)
          self[k].add_hash(v, as)
        else
          self[k].values[as] = v
        end
      end
    end

    def slice(key)
      @children.select { |k, v| v[key] }
    end

    def leaf?
      @children.empty?
    end

    def each(&block)
      @children.each_value { |v| yield v }
    end

    def summary(lev = 0)
      indent = "  " * lev
      out = [ ]

      @children.each_pair do |k, v|
        if v.leaf?
          case v.state
          when :added
            out << indent + "added #{k}: ".green + v.new.to_s
          when :removed
            out << indent + "removed #{k}: ".red + v.old.to_s
          when :changed
            out << indent + "changed #{k}: ".yellow + "#{v.old} -> #{v.new}"
          when :mismatch
            out << indent + "type mismatch in #{k}: ".red + "#{v.old} (#{v.old.class}) -> #{v.new} (#{v.new.class})"
          end
        else
          child_summary = v.summary(lev+1)
          unless child_summary.empty?
            out << indent + k
            out << child_summary
          end
        end
      end
      out
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
      elsif old.class != new.class
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
  end
end
