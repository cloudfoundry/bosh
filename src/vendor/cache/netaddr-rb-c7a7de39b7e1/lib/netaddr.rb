require 'time'
require 'digest/sha1'
require File.join(File.dirname(__FILE__), 'validation_shortcuts.rb')
require File.join(File.dirname(__FILE__), 'ip_math.rb')
require File.join(File.dirname(__FILE__), 'cidr_shortcuts.rb')
require File.join(File.dirname(__FILE__), 'methods.rb')
require File.join(File.dirname(__FILE__), 'cidr.rb')
require File.join(File.dirname(__FILE__), 'tree.rb')
require File.join(File.dirname(__FILE__), 'eui.rb')

module NetAddr

  class BoundaryError < StandardError #:nodoc:
  end

  class ValidationError < StandardError #:nodoc:
  end

  class VersionError < StandardError #:nodoc:
  end

end # module NetAddr

__END__
