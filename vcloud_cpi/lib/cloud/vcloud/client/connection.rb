$:.unshift(File.join(File.dirname(__FILE__), '.'))
$:.unshift(File.join(File.dirname(__FILE__), 'connection'))

require 'connection/connection'
require 'connection/file_uploader'
