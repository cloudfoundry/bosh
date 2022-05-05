module NetAddr
private

# validate options hash 
#
def validate_args(to_validate,known_args)
    to_validate.each do |x|
        raise ArgumentError, "Unrecognized argument #{x}. Valid arguments are " +
                             "#{known_args.join(',')}" if (!known_args.include?(x))
    end
end 
module_function :validate_args

def validate_ip_int(ip,version)
    version = 4 if (!version && ip < 2**32)
    if (version == 4)
        raise ValidationError, "#{ip} is invalid for IPv4 (Integer is out of bounds)." if ( (ip < 0) || (ip > 2**32-1) )
    else
        raise ValidationError, "#{ip} is invalid for both IPv4 and IPv6 (Integer is out of bounds)." if ( (ip < 0) || (ip > 2**128-1) )
        version = 6
    end
    return(version)
end
module_function :validate_ip_int

def validate_ip_str(ip,version)
    # check validity of charaters
    if (ip =~ /[^0-9a-fA-F\.:]/)
        raise ValidationError, "#{ip} is invalid (contains invalid characters)."
    end

    if (version == 4)
        octets = ip.split('.')
        raise ValidationError, "#{ip} is invalid (IPv4 requires (4) octets)." if (octets.length != 4)

        # are octets in range 0..255?
        octets.each do |octet|
            raise ValidationError, "#{ip} is invalid (IPv4 dotted-decimal format " +
                                   "should not contain non-numeric characters)." if (octet =~ /[\D]/ || octet == '')
            octet = octet.to_i()
            if ( (octet < 0) || (octet >= 256) )
                raise ValidationError, "#{ip} is invalid (IPv4 octets should be between 0 and 255)."
            end
        end

    else
            # make sure we only have at most (2) colons in a row, and then only
            # (1) instance of that
            if ( (ip =~ /:{3,}/) || (ip.split("::").length > 2) )
                raise ValidationError, "#{ip} is invalid (IPv6 field separators (:) are bad)."
            end

            # set flags
            shorthand = false
            if (ip =~ /\./)
                dotted_dec = true 
            else
                dotted_dec = false
            end

            # split up by ':'
            fields = []
            if (ip =~ /::/)
                shorthand = true
                ip.split('::').each do |x|
                    fields.concat( x.split(':') )
                end
            else
               fields.concat( ip.split(':') ) 
            end

            # make sure we have the correct number of fields
            if (shorthand)
                if ( (dotted_dec && fields.length > 6) || (!dotted_dec && fields.length > 7) )
                    raise ValidationError, "#{ip} is invalid (IPv6 shorthand notation has " +
                                           "incorrect number of fields)." 
                end
            else
                if ( (dotted_dec && fields.length != 7 ) || (!dotted_dec && fields.length != 8) )
                    raise ValidationError, "#{ip} is invalid (IPv6 address has " +
                                           "incorrect number of fields)." 
                end
            end

            # if dotted_dec then validate the last field
            if (dotted_dec)
                dotted = fields.pop()
                octets = dotted.split('.')
                raise ValidationError, "#{ip} is invalid (Legacy IPv4 portion of IPv6 " +
                                       "address should contain (4) octets)." if (octets.length != 4)
                octets.each do |x|
                    raise ValidationError, "#{ip} is invalid (egacy IPv4 portion of IPv6 " +
                                           "address should not contain non-numeric characters)." if (x =~ /[^0-9]/ )
                    x = x.to_i
                    if ( (x < 0) || (x >= 256) )
                        raise ValidationError, "#{ip} is invalid (Octets of a legacy IPv4 portion of IPv6 " +
                                               "address should be between 0 and 255)."
                    end
                end
            end

            # validate hex fields
            fields.each do |x|
                if (x =~ /[^0-9a-fA-F]/)
                    raise ValidationError, "#{ip} is invalid (IPv6 address contains invalid hex characters)."
                else
                    x = x.to_i(16)
                    if ( (x < 0) || (x >= 2**16) )
                        raise ValidationError, "#{ip} is invalid (Fields of an IPv6 address " +
                                               "should be between 0x0 and 0xFFFF)."
                    end
                end
            end

    end
    return(true)
end
module_function :validate_ip_str

def validate_netmask_int(netmask,version,is_int=false)
    address_len = 32
    address_len = 128 if (version == 6)

    if (!is_int)
        if (netmask > address_len || netmask < 0 )
            raise ValidationError, "Netmask, #{netmask}, is out of bounds for IPv#{version}." 
        end
    else
        if (netmask >= 2**address_len || netmask < 0 )
            raise ValidationError, "netmask (#{netmask}) is out of bounds for IPv#{version}."
        end
    end
    return(true)
end
module_function :validate_netmask_int

def validate_netmask_str(netmask,version)
    address_len = 32
    address_len = 128 if (version == 6)

    if(netmask =~ /\./) # extended netmask
        all_f = 2**32-1
        netmask_int = 0

        # validate & pack extended mask
        begin
            netmask_int = NetAddr.ip_to_i(netmask, :Version => 4)
        rescue Exception => error
          raise ValidationError, "#{netmask} is improperly formed: #{error}"
        end

        # cycle through the bits of hostmask and compare
        # with netmask_int. when we hit the firt '1' within
        # netmask_int (our netmask boundary), xor hostmask and
        # netmask_int. the result should be all 1's. this whole
        # process is in place to make sure that we dont have
        # and crazy masks such as 255.254.255.0
        hostmask = 1
         32.times do 
            check = netmask_int & hostmask
            if ( check != 0)
                hostmask = hostmask >> 1
                unless ( (netmask_int ^ hostmask) == all_f)
                    raise ValidationError, "#{netmask} contains '1' bits within the host portion of the netmask." 
                end
                break
            else
                hostmask = hostmask << 1
                hostmask = hostmask | 1
            end
        end

    else # cidr format
        # remove '/' if present
        if (netmask =~ /^\// )
            netmask[0] = " "
            netmask.lstrip!
        end

        # check if we have any non numeric characters
        if (netmask =~ /\D/)
            raise ValidationError, "#{netmask} contains invalid characters."
        end

        netmask = netmask.to_i
        if (netmask > address_len || netmask < 0 )
            raise ValidationError, "Netmask, #{netmask}, is out of bounds for IPv#{version}." 
        end

    end
    return(true)
end
module_function :validate_netmask_str



end # module NetAddr

__END__


