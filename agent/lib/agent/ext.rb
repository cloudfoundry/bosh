class Object
 def to_openstruct
   self
 end
end

class Array
 def to_openstruct
   map{ |el| el.to_openstruct }
 end
end

class Hash
  def recursive_merge!(other)
    self.merge!(other) do |_, old_value, new_value|
      if old_value.class == Hash
        old_value.recursive_merge!(new_value)
      else
        new_value
      end
    end
    self
  end

 def to_openstruct
   mapped = {}
   each{ |key,value| mapped[key] = value.to_openstruct }
   OpenStruct.new(mapped)
 end
end

class Logger
  BOSH_PATH = %r{\A/var/vcap/bosh/}
  def format_message(severity, timestamp, msg, progname)
    "#{Kernel.caller[2].gsub(BOSH_PATH, '')}: [##{$$}] #{severity.upcase}: #{progname.gsub(/\n/, '').lstrip}\n"
  end
end

