module NetAddr
private


# IP MATH METHODS

# given an integer and number of bits to consider, return its binary mirror
#
def binary_mirror(num, bit_count)
    mirror = 0
    bit_count.times do # make mirror image of num by capturning lsb and left-shifting it onto mirror
        mirror = mirror << 1
        lsb = num & 1
        num = num >> 1
        mirror = mirror | lsb
    end
    return(mirror)
end
module_function :binary_mirror

# convert a netmask (in bits) to an integer mask
#
def bits_to_mask(netmask,version)
    return(0) if (netmask == 0)
    all_f = 2**32-1
    all_f = 2**128-1 if (version == 6)
    return( all_f ^ (all_f >> netmask) )
end
module_function :bits_to_mask

# determine the ip version from ip address string.
#
# return 4, 6, or nil
#
def detect_ip_version(ip)
    version = nil
    if ( ip =~ /\./ && ip !~ /:/ )
        version = 4
    elsif (ip =~ /:/)
        version = 6
    else
        raise ValidationError, "Could not auto-detect IP version for '#{ip}'."
    end
    return(version)
end
module_function :detect_ip_version

# given an ip count, determine the most appropriate mask (in bits)
#
def ip_count_to_size(ipcount,version,extended=false)
    address_len = 32
    address_len = 128 if (version == 6 )

    if (ipcount > 2**address_len) 
        raise BoundaryError, "Required IP count exceeds number of IP addresses available " +
                             "for IPv#{version}."
    end

    bits_needed = 0
    until (2**bits_needed >= ipcount)
        bits_needed += 1
    end
    subnet_bits = address_len - bits_needed

    return( ip_int_to_str(bits_to_mask(subnet_bits, 4), 4) ) if (extended && version == 4)
    return(subnet_bits)
end
module_function :ip_count_to_size

# unpack an int into an ip address string
#
def ip_int_to_str(ip_int, version, ipv4_mapped=nil)
    ip = nil
    version = 4 if (!version && ip_int < 2**32)
    if (version == 4)
        octets = []
        4.times do
            octet = ip_int & 0xFF
            octets.unshift(octet.to_s)
            ip_int = ip_int >> 8
        end
        ip = octets.join('.')
    else
        fields = []
        if (!ipv4_mapped)
            loop_count = 8
        else
            loop_count = 6
            ipv4_int = ip_int & 0xffffffff
            ipv4_addr = ip_int_to_str(ipv4_int, 4)
            fields.unshift(ipv4_addr)
            ip_int = ip_int >> 32
        end

        loop_count.times do 
            octet = ip_int & 0xFFFF
            octet = octet.to_s(16)
            ip_int = ip_int >> 16

            # if octet < 4 characters, then pad with 0's
            (4 - octet.length).times do
                octet = '0' << octet
            end
            fields.unshift(octet)
        end
        ip = fields.join(':')
    end
    return(ip)
end
module_function :ip_int_to_str

# convert an ip string into an int
#
def ip_str_to_int(ip,version)
    ip_int = 0
    if ( version == 4)
        octets = ip.split('.')
        (0..3).each do |x|
            octet = octets.pop.to_i
            octet = octet << 8*x
            ip_int = ip_int | octet
        end

    else
        # if ipv4-mapped ipv6 addr
        if (ip =~ /\./)
            dotted_dec = true
        end

        # split up by ':'
        fields = []
        if (ip =~ /::/)
           shrthnd = ip.split( /::/ )
            if (shrthnd.length == 0)
                return(0)
            else
                first_half = shrthnd[0].split( /:/ ) if (shrthnd[0])
                sec_half = shrthnd[1].split( /:/ ) if (shrthnd[1])
                first_half = [] if (!first_half)
                sec_half = [] if (!sec_half)
            end
            missing_fields = 8 - first_half.length - sec_half.length
            missing_fields -= 1 if dotted_dec
            fields = fields.concat(first_half)
            missing_fields.times {fields.push('0')}
            fields = fields.concat(sec_half)

        else
           fields = ip.split(':')
        end

        if (dotted_dec)
            ipv4_addr = fields.pop
            ipv4_int = NetAddr.ip_to_i(ipv4_addr, :Version => 4)
            octets = []
            2.times do
                octet = ipv4_int & 0xFFFF
                octets.unshift(octet.to_s(16))
                ipv4_int = ipv4_int >> 16
            end
            fields.concat(octets)
        end

        # pack
        (0..7).each do |x|
            field = fields.pop.to_i(16)
            field = field << 16*x
            ip_int = ip_int | field
        end

   end
    return(ip_int)
end
module_function :ip_str_to_int

# convert integer into a cidr formatted netmask (bits)
#
def mask_to_bits(netmask_int)
    return(netmask_int) if (netmask_int == 0)

    mask = nil
    if (netmask_int < 2**32)
        mask = 32
        validate_netmask_int(netmask_int, 4, true)
    else
        mask = 128
        validate_netmask_int(netmask_int, 6, true)
    end

    mask.times do
        if ( (netmask_int & 1) == 1)
            break
        end
        netmask_int = netmask_int >> 1
        mask = mask - 1
    end
    return(mask)
end
module_function :mask_to_bits

# convert string into integer mask
#
def netmask_str_to_int(netmask,version)
    netmask_int = nil
    all_f = 2**32-1
    all_f = 2**128-1 if (version == 6)
    if(netmask =~ /\./)
        netmask_int = NetAddr.ip_to_i(netmask)
    else
        # remove '/' if present
        if (netmask =~ /^\// )
            netmask[0] = " "
            netmask.lstrip!
        end
        netmask = netmask.to_i
        netmask_int = all_f ^ (all_f >> netmask)
    end
    return(netmask_int)
end
module_function :netmask_str_to_int



end # module NetAddr

__END__

