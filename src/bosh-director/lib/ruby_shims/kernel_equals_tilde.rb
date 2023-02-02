# Prior to ruby 3.2, =~ returned nil by default. You should be calling =~ on a string or a regular expression and this code should not be reached
# https://bugs.ruby-lang.org/issues/15231
module Kernel
  def =~(_)
    nil
  end
end
