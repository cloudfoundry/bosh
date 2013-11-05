# The AWS and VirtualBox boxes differ here
# AWS needs this to source /etc/profile when executing non-interactive sudo
# This is needed for go to be added to the PATH
group 'sudo' do
  action :modify
  members 'ubuntu'
  append true
end