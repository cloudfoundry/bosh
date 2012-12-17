#!/usr/bin/env ruby
#
# setup warden

require 'fileutils'

def kernel_version_match?
    os=(%x{uname -r}).chop
    p os
    os = os.split '.'
        if Integer(os[0]) >=2 && Integer(os[1]) >= 6 &&Integer(os[2].split('-')[0])>=38
           return true
        end
    return false
end

local_gem_list = %x{gem list}
bundler_pattern = /^bundler \([0-9\.\s\,]+\)$/

unless bundler_pattern.match(local_gem_list)
  p 'install required gems git and bundler'
  %x{gem install bundler}
end

p 'install required package'
%x{sudo apt-get --force-yes -y install -y libnl1 quota}
%x{sudo apt-get --force-yes -y install git-core}

unless kernel_version_match?
  p 'If you are running Ubuntu 10.04 (Lucid), make sure the backported Natty kernel is installed. After installing, reboot the system before continuing. install the kernel using the following command: sudo apt-get install -y linux-image-generic-lts-backport-natty'
  exit
end

p 'git clone warden code'
p 'input where to checkout source code[/tmp/workspace]:'

@dirPath = gets
@dirPath=@dirPath.chop
FileUtils.mkdir_p(@dirPath)
FileUtils.chdir(@dirPath)
p %x{pwd}
%x{git clone https://github.com/cloudfoundry/warden.git}
FileUtils.chdir(@dirPath+"/warden/warden")

p 'bundler setup'
%x{sudo env PATH=$PATH bundle install}

p 'setup warden'
system 'sudo env PATH=$PATH bundle exec rake setup[config/linux.yml]'

p 'start warden'
system 'sudo env PATH=$PATH bundle exec rake warden:start[config/linux.yml]'
