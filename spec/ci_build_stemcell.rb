#!/usr/bin/env ruby
require 'fileutils'

FileUtils.rm_rf('*.tgz')

if ARGV[0] == 'micro'
  task = 'micro'
else
  task = 'basic'
end

if ARGV[1]
  infrastructure = ARGV[1]
else
  infrastructure = 'aws'
end

directory = File.join('/mnt/stemcells', "#{infrastructure}-#{task}")
system("sudo umount #{File.join(directory, 'work/work/mnt/tmp/grub/root.img')} 2>/dev/null")
system("sudo umount #{File.join(directory, 'work/work/mnt')} 2>/dev/null")

mnt_type = `df -T '#{directory}' | awk '/dev/{ print $2 }'`
mnt_type = 'unknown' if mnt_type.strip.empty?

if mnt_type != 'btrfs'
  system("sudo rm -rf #{directory}")
end

cmd = "WORK_PATH=#{directory}/work BUILD_PATH=#{directory}/build STEMCELL_VERSION=$BUILD_ID $WORKSPACE/spec/ci_build.sh ci:stemcell:#{task}[#{infrastructure}]"

system(cmd) || raise("command failed: #{cmd.inspect}")

files = Dir.glob("#{directory}/work/work/*.tgz")

unless files.empty?
  stemcell = files.first
  stemcell_base = File.basename(stemcell, '.tgz')

  FileUtils.cp(stemcell, File.join(ENV.to_hash.fetch('WORKSPACE'), "#{stemcell_base}.tgz"))

  if infrastructure == 'aws'
    system("bundle exec rake --trace artifacts:candidates:publish[$WORKSPACE/#{stemcell_base}.tgz]")
  end
end
