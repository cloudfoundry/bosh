Three steps to create the vmdk template file, i.e. env.vmdk and env-flat.vmdk
(1) Convert a file with content, such as environment settings, to an iso file
Tool: genisoimage (ref: http://linux.die.net/man/1/genisoimage)
Command: `genisoimage -o #{iso_file_path} #{original_file_path}`

(2) Convert the iso file to one vmdk file
Tool: qemu-img (To install, run `sudo apt-get install qemu`)
Command: `qemu-img convert -O vmdk #{iso_file} #{env.vmdk}`

(3) Convert the vmdk file to esx type vmdk files (one descriptor file, i.e. env.vmdk and one content file, i.e. env-flat.vmdk)
 Tools: vmware-vdiskmanager (VMware Virtual Disk Manager, ref: http://www.vmware.com/pdf/VirtualDiskManager.pdf)
 Command: `vmware-vdiskmanager -r #{original_vmdk_file} -t 4 #{new_vmdk_file}`



