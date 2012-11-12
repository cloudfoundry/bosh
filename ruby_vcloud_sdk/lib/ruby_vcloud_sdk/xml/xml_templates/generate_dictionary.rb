puts "XML_TYPE = {"

Dir["*.xml"].each do |f|
  name = File.basename(f, ".xml")
  puts %Q[:#{name.upcase} => "#{name}",]
end

puts "}"
