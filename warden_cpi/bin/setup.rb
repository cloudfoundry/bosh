#!/usr/bin/env ruby
#
# setup warden

require 'fileutils'

DEFAULT_WARDEN_DIRPATH = '/tmp/workspace'

#only support ubunut with kernel version 2.6.38 or above
def kernel_version_match?
  os = (%x{uname -r}).chop
  os = os.split '.'
  if Integer(os[0]) >=2 && Integer(os[1]) >= 6 && Integer(os[2].split('-')[0])>=38
    return true
  end
  return false
end

p 'install required package'
%x{sudo apt-get --force-yes -y install libnl1 quota}
%x{sudo apt-get --force-yes -y install git-core}

unless kernel_version_match?
  p 'If you are running Ubuntu 10.04 (Lucid), make sure the backported Natty kernel is installed. After installing, reboot the system before continuing. install the kernel using the following command: sudo apt-get install -y linux-image-generic-lts-backport-natty'
  exit
end

if ARGV[0].nil?
  p 'please specify where to git clone warden code like following command: ruby setup.rb your/path '
  exit
end

@dirPath = ARGV[0]
p @dirPath
FileUtils.mkdir_p(@dirPath)
FileUtils.chdir(@dirPath)
p 'git clone warden code'
%x{git clone https://github.com/cloudfoundry/warden.git}
FileUtils.chdir(File.join(@dirPath,"warden","warden"))

p 'bundler setup'
%x{sudo env PATH=$PATH bundle install}

p 'setup warden'
@config_file = ARGV[1].nil? ? 'config/linux.yml' : ARGV[1]
setup_warden_cmd = "sudo env PATH=$PATH bundle exec rake setup[#{@config_file}]"
system setup_warden_cmd
