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

    def keys
      @children.keys
    end

    def []=(key, value)
      @children[key.to_s] = value
    end

    def add_hash(hash, as)
      raise FormatError, "Trying to add #{hash.class} to a changeset, Hash expected" unless hash.is_a?(Hash)

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

    def summary(lev = 0)
      indent = "  " * lev
      out = [ ]

      @children.each_pair do |k, v|
        if v.state == :mismatch
          out << indent + "type mismatch in #{k}: ".red + "was #{v.old.class.to_s}, now #{v.new.class.to_s}"
          out << diff(v.old, v.new, indent + "  ")
        elsif v.leaf?
          case v.state
          when :added
            out << indent + "added #{k}: ".yellow + v.new.to_s
          when :removed
            out << indent + "removed #{k}: ".red + v.old.to_s
          when :changed
            out << indent + "changed #{k}: ".yellow
            out << diff(v.old, v.new, indent + "  ")
          end
        else
          # TODO: track renames?
          child_summary = v.summary(lev+1)

          unless child_summary.empty?
            out << indent + k
            out << child_summary
          end
        end
      end
      out
    end

    def diff(oldval, newval, indent)
      oldval  = [ oldval ] unless oldval.kind_of?(Array)
      newval  = [ newval ] unless newval.kind_of?(Array)

      added   = newval - oldval
      removed = oldval - newval

      lines = []

      removed.each do |line|
        lines << "#{indent}- #{line}".red
      end

      added.each do |line|
        lines << "#{indent}+ #{line}".green
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
