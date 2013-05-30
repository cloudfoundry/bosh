def update_bosh_version(version_number)
  file_contents = File.read("BOSH_VERSION")
  file_contents.gsub!(/^([\d\.]+)\.pre\.\d+$/, "\\1.pre.#{version_number}")
  File.open("BOSH_VERSION", 'w') { |f| f.write file_contents }
end