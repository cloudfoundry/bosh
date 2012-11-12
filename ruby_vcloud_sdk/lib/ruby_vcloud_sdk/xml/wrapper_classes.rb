$:.unshift(File.join(File.dirname(__FILE__), "wrapper_classes"))

Dir[File.dirname(__FILE__) + "/wrapper_classes/*.rb"].each { |r| require File.expand_path(r) }