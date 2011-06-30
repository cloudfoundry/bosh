class Object
 def to_openstruct
   self
 end

  def blank?
    self.to_s.blank?
  end
end

class String
  def blank?
    self =~ /^\s*$/
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
  def format_message(severity, timestamp, progname, msg)
    "#[#{$$}] #{severity.upcase}: #{msg}\n"
  end
end
