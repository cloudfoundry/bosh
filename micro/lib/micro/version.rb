module VCAP
  module Micro
    class Version
      VERSION = "1.1.0_alpha1"
      FILE_REGEXP = /micro-(\d+\.\d+\.*\d*_*\S*)\.tgz/
      VERSION_REGEXP = /(\d+)\.(\d+)\.*(\d+)*_*(\S*)/

      # converts the full filename to just version number, e.g.
      # "micro-1.0.0_rc2.tgz" -> "1.0.0 rc2""
      def self.file2version(filename)
        return nil if filename.nil?
        if version = filename.match(FILE_REGEXP)
          if matches = version[1].match(VERSION_REGEXP)
            v = "#{matches[1]}"
            v += ".#{matches[2]}" if matches[2]
            v += ".#{matches[3]}" if matches[3]
            v += " #{matches[4]}" if matches[4] && !matches[4].empty?
            v
          end
        end
      end

      def self.should_update?(matcher, installed=VERSION)
        inst = installed.match(VERSION_REGEXP)
        m = matcher.match(VERSION_REGEXP)
        ok = true
        ok = (inst[1] >= m[1]) if m[1]
        ok = ok && (inst[2] >= m[2]) if m[2]
        ok = ok && (inst[3] >= m[3]) if m[3]
        !ok
      end
    end
  end
end
