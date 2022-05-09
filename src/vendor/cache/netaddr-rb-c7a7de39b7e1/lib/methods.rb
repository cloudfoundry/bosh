module NetAddr

#===Synopsis
#Convert an Integer representing a binary netmask into an Integer representing
#the number of bits in that netmask.
#
# Example:
# NetAddr.i_to_bits(0xfffffffe) => 31
# NetAddr.i_to_bits(0xffffffffffffffff0000000000000000) => 64
#
#===Arguments:
#* netmask_int = Integer representing a binary netmask
#
#===Returns:
#* Integer
#
def i_to_bits(netmask_int)

    # validate netmask_int
    raise ArgumentError, "Integer expected for argument 'netmask_int', " +
                         "but #{netmask_int.class} provided." if (!netmask_int.kind_of?(Integer))    


    return( mask_to_bits(netmask_int) )
end
module_function :i_to_bits

#===Synopsis
#Convert an Integer into an IP address. This method will attempt to auto-detect the IP version
#if not provided, however, a slight speed increase is realized if version is provided.
#
# Example:
# NetAddr.i_to_ip(3232235906) => "192.168.1.130"
# NetAddr.i_to_ip(0xffff0000000000000000000000000001, :Version => 6) => "ffff:0000:0000:0000:0000:0000:0000:0001"
#
#===Arguments:
#* ip_int = IP address as an Integer
#* options = Hash with the following keys:
#     :Version -- IP version - Integer (optional)
#     :IPv4Mapped -- if true, unpack IPv6 as an IPv4 mapped address (optional)
#
#===Returns:
#* String
#
def i_to_ip(ip_int, options=nil)
    known_args = [:Version, :IPv4Mapped]
    ipv4_mapped = false
    version = nil

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Version))
            version = options[:Version]
            if (version != 4 && version != 6)
                raise VersionError, ":Version should be 4 or 6, but was '#{version}'."
            end
        end

        if (options.has_key?(:IPv4Mapped) && options[:IPv4Mapped] == true)
            ipv4_mapped = true
        end
    end

    # validate & unpack
    raise ArgumentError, "Integer expected for argument 'ip_int', " +
                         "but #{ip_int.class} provided." if (!ip_int.kind_of?(Integer))
    version = validate_ip_int(ip_int, version)
    ip = ip_int_to_str(ip_int, version, ipv4_mapped)

    return(ip)
end
module_function :i_to_ip

#===Synopsis
#Convert IP addresses into an Integer. This method will attempt to auto-detect the IP version
#if not provided, however a slight speed increase is realized if version is provided.
#
# Example:
# NetAddr.ip_to_i('192.168.1.1') => 3232235777
# NetAddr.ip_to_i('ffff::1', :Version => 6) => 340277174624079928635746076935438991361
# NetAddr.ip_to_i('::192.168.1.1') => 3232235777
#
#===Arguments:
#* ip = IP address as a String
#* options = Hash with the following keys:
#     :Version -- IP version - Integer
#
#===Returns:
#* Integer
#
def ip_to_i(ip, options=nil)
    known_args = [:Version]
    to_validate = {}
    version = nil

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        validate_args(options.keys,known_args)

        if (options.has_key?(:Version))
            version = options[:Version]
            to_validate[:Version] = version
            if (version != 4 && version != 6)
                raise  VersionError, ":Version should be 4 or 6, but was '#{version}'."
            end
        end
    end

    if ( ip.kind_of?(String) )
        version = detect_ip_version(ip) if (!version)
        validate_ip_str(ip,version)
        ip_int = ip_str_to_int(ip,version)

    else
        raise ArgumentError, "String expected for argument 'ip' but #{ip.class} provided."
    end

    return(ip_int)
end
module_function :ip_to_i

#===Synopsis
#Given a list of CIDR addresses or NetAddr::CIDR objects,
#merge (summarize) them in the most efficient way possible. Summarization 
#will only occur when the newly created supernets will not result in the 
#'creation' of new IP space. For example the following blocks 
#(192.168.0.0/24, 192.168.1.0/24, and 192.168.2.0/24) would be summarized into 
#192.168.0.0/23 and 192.168.2.0/24 rather than into 192.168.0.0/22 
#
#I have designed this with enough flexibility so that you can pass in CIDR 
#addresses that arent even related (ex. 192.168.1.0/26, 192.168.1.64/27, 192.168.1.96/27
#10.1.0.0/26, 10.1.0.64/26) and they will be merged properly (ie 192.168.1.0/25,
#and 10.1.0.0/25 would be returned).
#
#If the :Objectify option is enabled, then any summary addresses returned will
#contain the original CIDRs used to create them within the tag value :Subnets
#(ie. cidr_x.tag[:Subnets] would be an Array of the CIDRs used to create cidr_x)
#
# Example:
# cidr1 = NetAddr::CIDR.create('192.168.1.0/27')
# cidr2 = NetAddr::CIDR.create('192.168.1.32/27')
# NetAddr.merge([cidr1,cidr2])
# ip_net_range = NetAddr.range('192.168.35.0','192.168.39.255',:Inclusive => true, :Objectify => true)
# NetAddr.merge(ip_net_range, :Objectify => true)
#
#===Arguments:
#* list = Array of CIDR addresses as Strings, or an Array of NetAddr::CIDR objects 
#* options = Hash with the following keys:
#     :Objectify -- if true, return NetAddr::CIDR objects
#     :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of CIDR addresses or NetAddr::CIDR objects
#
def merge(list,options=nil)
    known_args = [:Objectify, :Short]
    short = false
    objectify = false
    verbose = false

    # validate list
    raise ArgumentError, "Array expected for argument 'list' but #{list.class} provided." if (!list.kind_of?(Array) )

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash) )
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Objectify) && options[:Objectify] == true)
            objectify = true
        end

        if (options.has_key?(:Short) && options[:Short] == true)
            short = true 
        end
    end

    # make sure all are valid types of the same IP version
    v4_list = []
    v6_list = []
    list.each do |obj|
        if (!obj.kind_of?(NetAddr::CIDR))
            begin
                obj = NetAddr::CIDR.create(obj)
            rescue Exception => error
                raise ArgumentError, "One of the provided CIDR addresses raised the following " +
                                     "errors: #{error}"
            end
        end

        if (obj.version == 4)
            v4_list.push(obj)
        else
            v6_list.push(obj)
        end
    end

    # summarize
    v4_summary = []
    v6_summary = []
    if (v4_list.length != 0)
        v4_summary = NetAddr.cidr_summarize(v4_list)
    end

    if (v6_list.length != 0)
        v6_summary = NetAddr.cidr_summarize(v6_list)
    end

    # decide what to return
    summarized_list = []
    if (!objectify)
        summarized_list = []
        if (v4_summary.length != 0)
            v4_summary.each {|x| summarized_list.push(x.desc())}
        end

        if (v6_summary.length != 0)
            v6_summary.each {|x| summarized_list.push(x.desc(:Short => short))}
        end

    else
        summarized_list.concat(v4_summary) if (v4_summary.length != 0)
        summarized_list.concat(v6_summary) if (v6_summary.length != 0)
    end

    return(summarized_list)
end
module_function :merge

#===Synopsis
#Given the number of IP addresses required in a subnet, return the minimum
#netmask (bits by default) required for that subnet. IP version is assumed to be 4 unless specified otherwise.
#
# Example:
# NetAddr.minimum_size(14) => 28
# NetAddr.minimum_size(65536, :Version => 6) => 112
#
#===Arguments:
#* ipcount = IP count as an Integer
#* options = Hash with the following keys:
#     :Extended -- If true, then return the netmask, as a String, in extended format (IPv4 only y.y.y.y)
#     :Version -- IP version - Integer
#
#===Returns:
#* Integer or String
#
def minimum_size(ipcount, options=nil)
    version = 4
    extended = false
    known_args = [:Version, :Extended]

    # validate ipcount
    raise ArgumentError, "Integer expected for argument 'ipcount' but #{ipcount.class} provided." if (!ipcount.kind_of?(Integer))

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))

        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Version))
            version = options[:Version]
        end

        if (options.has_key?(:Extended) && options[:Extended] == true)
            extended = true
        end
    end

    return( ip_count_to_size(ipcount,version,extended) )
end
module_function :minimum_size

#===Synopsis
#Convert IP netmask into an Integer. Netmask may be in either CIDR (/yy) or
#extended (y.y.y.y) format. CIDR formatted netmasks may either
#be a String or an Integer. IP version defaults to 4. It may be necessary
#to specify the version if an IPv6 netmask of /32 or smaller is provided.
#
# Example:
# NetAddr.netmask_to_i('255.255.255.0') => 4294967040
# NetAddr.netmask_to_i('24') => 4294967040
# NetAddr.netmask_to_i(24) => 4294967040
# NetAddr.netmask_to_i('/24') => 4294967040
# NetAddr.netmask_to_i('32', :Version => 6) => 340282366841710300949110269838224261120
#
#===Arguments
#* netmask = Netmask as a String or Integer
#* options = Hash with the following keys:
#     :Version -- IP version - Integer
#
#===Returns:
#* Integer
#
def netmask_to_i(netmask, options=nil)
    known_args = [:Version]
    version = 4
    netmask_int = nil

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Version))
            version = options[:Version]
            if (version != 4 && version != 6)
                raise VersionError, ":Version should be 4 or 6, but was '#{version}'."
            end
        end
    end

    if (netmask.kind_of?(String))
        validate_netmask_str(netmask, version)
        netmask_int = netmask_str_to_int(netmask,version)

    elsif (netmask.kind_of?(Integer))
        validate_netmask_int(netmask, version, true)
        netmask_int = bits_to_mask(netmask,version)

    else
        raise ArgumentError, "String or Integer expected for argument 'netmask', " +
                             "but #{netmask.class} provided." if (!netmask.kind_of?(Integer) && !netmask.kind_of?(String))
    end

    return(netmask_int)
end
module_function :netmask_to_i

#===Synopsis
#Given two CIDR addresses or NetAddr::CIDR objects of the same version,
#return all IP addresses between them. NetAddr.range will use the original IP 
#address passed during the initialization of the NetAddr::CIDR objects, or the 
#IP address portion of any CIDR addresses passed. The default behavior is to be 
#non-inclusive (don't include boundaries as part of returned data).
#
# Example:
# lower = NetAddr::CIDR.create('192.168.35.0')
# upper = NetAddr::CIDR.create('192.168.39.255')
# NetAddr.range(lower,upper, :Limit => 10, :Bitstep => 32)
# NetAddr.range('192.168.35.0','192.168.39.255', :Inclusive => true)
# NetAddr.range('192.168.35.0','192.168.39.255', :Inclusive => true, :Size => true)
#
#===Arguments:
#* lower = Lower boundary CIDR as a String or NetAddr::CIDR object
#* upper = Upper boundary CIDR as a String or NetAddr::CIDR object
#* options = Hash with the following keys:
#     :Bitstep -- enumerate in X sized steps - Integer
#     :Inclusive -- if true, include boundaries in returned data
#     :Limit -- limit returned list to X number of items - Integer
#     :Objectify -- if true, return CIDR objects
#     :Short -- if true, return IPv6 addresses in short-hand notation
#     :Size -- if true, return the number of addresses in this range, but not the addresses themselves
#
#===Returns:
#* Array of Strings or NetAddr::CIDR objects, or an Integer
#
#===Note:
#If you do not need all of the fancy options in this method, then please consider
#using the standard Ruby Range class as shown below.
#
# Example:
# start = NetAddr::CIDR.create('192.168.1.0')
# fin = NetAddr::CIDR.create('192.168.2.3')
# (start..fin).each {|addr| puts addr.desc}
#
def range(lower, upper, options=nil)
    known_args = [:Bitstep, :Inclusive, :Limit, :Objectify, :Short, :Size]
    list = []
    bitstep = 1
    objectify = false
    short = false
    size_only = false
    inclusive = false
    limit = nil

    # if lower/upper are not CIDR objects, then attempt to create
    # cidr objects from them
    if ( !lower.kind_of?(NetAddr::CIDR) )
        begin
            lower = NetAddr::CIDR.create(lower)
        rescue Exception => error
            raise ArgumentError, "Argument 'lower' raised the following " +
                                 "errors: #{error}"
        end
    end

    if ( !upper.kind_of?(NetAddr::CIDR))
        begin
            upper = NetAddr::CIDR.create(upper)
        rescue Exception => error
            raise ArgumentError, "Argument 'upper' raised the following " +
                                 "errors: #{error}"
        end
    end

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if( options.has_key?(:Bitstep) )
            bitstep = options[:Bitstep]
        end

        if( options.has_key?(:Objectify) && options[:Objectify] == true )
            objectify = true
        end

        if( options.has_key?(:Short) && options[:Short] == true )
            short = true 
        end

        if( options.has_key?(:Size) && options[:Size] == true )
            size_only = true 
        end

        if( options.has_key?(:Inclusive) && options[:Inclusive] == true )
            inclusive = true
        end

        if( options.has_key?(:Limit) )
            limit = options[:Limit]
        end
    end

    # check version, store & sort
    if (lower.version == upper.version)
        version = lower.version
        boundaries = [lower.to_i(:ip), upper.to_i(:ip)]
        boundaries.sort
    else
        raise VersionError, "Provided NetAddr::CIDR objects are of different IP versions."
    end

    # dump our range
    if (!inclusive)
        my_ip = boundaries[0] + 1
        end_ip = boundaries[1]
    else
        my_ip = boundaries[0]
        end_ip = boundaries[1] + 1
    end

    if (!size_only)
        until (my_ip >= end_ip) 
            if (!objectify)
                my_ip_s = ip_int_to_str(my_ip, version)
                my_ips = shorten(my_ips) if (short && version == 6)
                list.push(my_ip_s)
            else
                list.push( cidr_build(version,my_ip) )
            end

            my_ip = my_ip + bitstep
            if (limit)
                limit = limit - 1
                break if (limit == 0)
            end
        end
    else
        list = end_ip - my_ip
    end

    return(list)
end
module_function :range

#===Synopsis
#Take a standard IPv6 address and format it in short-hand notation.
#The address should not contain a netmask.
#
# Example:
# NetAddr.shorten('fec0:0000:0000:0000:0000:0000:0000:0001') => "fec0::1"
#
#===Arguments:
#* addr = String
#
#===Returns:
#* String
#
def shorten(addr)

    # is this a string?
    if (!addr.kind_of? String)
        raise ArgumentError, "Expected String, but #{addr.class} provided."
    end

    validate_ip_str(addr, 6)

    # make sure this isnt already shorthand
    if (addr =~ /::/)
        return(addr)
    end

    # split into fields
    fields = addr.split(":")

    # check last field for ipv4-mapped addr
    if (fields.last() =~ /\./ )
        ipv4_mapped = fields.pop()
    end

    # look for most consecutive '0' fields
    start_field,end_field = nil,nil
    start_end = []
    consecutive,longest = 0,0

    (0..(fields.length-1)).each do |x|
        fields[x] = fields[x].to_i(16)

        if (fields[x] == 0)
            if (!start_field)
                start_field = x
                end_field = x
            else
                end_field = x
            end
            consecutive += 1
        else
            if (start_field)
                if (consecutive > longest)
                    longest = consecutive
                    start_end = [start_field,end_field]
                    start_field,end_field = nil,nil
                end
                consecutive = 0
            end
        end

        fields[x] = fields[x].to_s(16)
    end

    # if our longest set of 0's is at the end, then start & end fields
    # are already set. if not, then make start & end fields the ones we've
    # stored away in start_end
    if (consecutive > longest) 
        longest = consecutive
    else
        start_field = start_end[0]
        end_field = start_end[1]
    end

    if (longest > 1)
        fields[start_field] = ''
        start_field += 1
        fields.slice!(start_field..end_field)
    end 
    fields.push(ipv4_mapped) if (ipv4_mapped)
    short = fields.join(':')
    short << ':' if (short =~ /:$/)

    return(short)
end
module_function :shorten

#===Synopsis
#Sort a list of CIDR addresses or NetAddr::CIDR objects,
#
# Example:
# cidr1 = NetAddr::CIDR.create('192.168.1.32/27')
# cidr2 = NetAddr::CIDR.create('192.168.1.0/27')
# NetAddr.sort([cidr1,cidr2])
# NetAddr.sort(['192.168.1.32/27','192.168.1.0/27','192.168.2.0/24'], :Desc => true)
#
#===Arguments:
#* list = Array of CIDR addresses as Strings, or Array of NetAddr::CIDR objects
#* options = Hash with the following keys:
#     :ByMask -- if true, sorts based on the netmask length
#     :Desc -- if true, return results in descending order
#
#===Returns:
#* Array of Strings, or Array of NetAddr::CIDR objects
#
def sort(list, options=nil)
    # make sure list is an array
    if ( !list.kind_of?(Array) )
        raise ArgumentError, "Array of NetAddr::CIDR or NetStruct " +
                             "objects expected, but #{list.class} provided."
    end

    desc = false
    by_mask = false
    # validate options
    if (options)
        known_args = [:Desc, :ByMask]
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if( options.has_key?(:Desc) && options[:Desc] == true )
            desc = true
        end

        if( options.has_key?(:ByMask) && options[:ByMask] == true )
            by_mask = true
        end

    end

    # make sure all are valid types of the same IP version
    version = nil
    cidr_hash = {}
    list.each do |cidr|
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                new_cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "An element of the provided Array " +
                                     "raised the following errors: #{error}"
            end
        else
            new_cidr = cidr
        end
        cidr_hash[new_cidr] = cidr

        version = new_cidr.version if (!version)
        unless (new_cidr.version == version)
            raise VersionError, "Provided CIDR addresses must all be of the same IP version."
        end 
    end

    # perform sort
    if (by_mask)
        sorted_list = netmask_sort(cidr_hash.keys, desc)
    else
        sorted_list = cidr_sort(cidr_hash.keys, desc)
    end

    # return original values passed
    ret_list = []
    sorted_list.each {|x| ret_list.push(cidr_hash[x])}

    return(ret_list)
end
module_function :sort

#===Synopsis
#Given a list of CIDR addresses or NetAddr::CIDR objects,
#return only the top-level supernet CIDR addresses.
#
#
#If the :Objectify option is enabled, then returned CIDR objects will
#store the more specific CIDRs (i.e. subnets of those CIDRs) within the tag value :Subnets
#For example, cidr_x.tag[:Subnets] would be an Array of CIDR subnets of cidr_x.
#
# Example:
# NetAddr.supernets(['192.168.0.0', '192.168.0.1', '192.168.0.0/31'])
#
#===Arguments:
#* list = Array of CIDR addresses as Strings, or an Array of NetAddr::CIDR objects 
#* options = Hash with the following keys:
#     :Objectify -- if true, return NetAddr::CIDR objects
#     :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of CIDR addresses or NetAddr::CIDR objects
#
def supernets(list,options=nil)
    known_args = [:Objectify, :Short]
    short = false
    objectify = false
    verbose = false

    # validate list
    raise ArgumentError, "Array expected for argument 'list' but #{list.class} provided." if (!list.kind_of?(Array) )

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash) )
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Objectify) && options[:Objectify] == true)
            objectify = true
        end

        if (options.has_key?(:Short) && options[:Short] == true)
            short = true 
        end
    end

    # make sure all are valid types of the same IP version
    v4_list = []
    v6_list = []
    list.each do |obj|
        if (!obj.kind_of?(NetAddr::CIDR))
            begin
                obj = NetAddr::CIDR.create(obj)
            rescue Exception => error
                raise ArgumentError, "One of the provided CIDR addresses raised the following " +
                                     "errors: #{error}"
            end
        end

        if (obj.version == 4)
            v4_list.push(obj)
        else
            v6_list.push(obj)
        end
    end

    # do summary calcs
    v4_summary = []
    v6_summary = []
    if (v4_list.length != 0)
        v4_summary = NetAddr.cidr_supernets(v4_list)
    end

    if (v6_list.length != 0)
        v6_summary = NetAddr.cidr_supernets(v6_list)
    end

    # decide what to return
    summarized_list = []
    if (!objectify)
        summarized_list = []
        if (v4_summary.length != 0)
            v4_summary.each {|x| summarized_list.push(x.desc())}
        end

        if (v6_summary.length != 0)
            v6_summary.each {|x| summarized_list.push(x.desc(:Short => short))}
        end

    else
        summarized_list.concat(v4_summary) if (v4_summary.length != 0)
        summarized_list.concat(v6_summary) if (v6_summary.length != 0)
    end

    return(summarized_list)
end
module_function :supernets

#===Synopsis
#Take an IPv6 address in short-hand format, and expand it into standard
#notation. The address should not contain a netmask.
#
# Example:
# NetAddr.unshorten('fec0::1') => "fec0:0000:0000:0000:0000:0000:0000:0001"
#
#===Arguments:
#* ip = CIDR address as a String
#
#===Returns:
#* String
#
def unshorten(ip)

    # is this a string?
    if (!ip.kind_of? String)
        raise ArgumentError, "Expected String, but #{ip.class} provided."
    end

    validate_ip_str(ip, 6)
    ipv4_mapped = true if (ip =~ /\./)

    ip_int = ip_to_i(ip, :Version => 6)
    if (!ipv4_mapped)
        long = ip_int_to_str(ip_int, 6)
    else
        long = ip_int_to_str(ip_int, 6, true)
    end

    return(long)
end
module_function :unshorten

#===Synopsis
#Validate an EUI-48 or EUI-64 address. Raises NetAddr::ValidationError on validation failure.
#
# Example:
# NetAddr.validate_eui('01-00-5e-12-34-56') => true
#
# - Arguments
#* eui = EUI address as a String
#
#===Returns:
#* True
#
def validate_eui(eui)
    if (eui.kind_of?(String))
        # check for invalid characters
        if (eui =~ /[^0-9a-fA-F\.\-\:]/)
            raise ValidationError, "#{eui} is invalid (contains invalid characters)."
        end

        # split on formatting characters & check lengths
        if (eui =~ /\-/)
            fields = eui.split('-')
            if (fields.length != 6 && fields.length != 8)
                raise ValidationError, "#{eui} is invalid (unrecognized formatting)."
            end
            fields.each {|x| raise ValidationError, "#{eui} is invalid (missing characters)." if (x.length != 2)} 
        elsif (eui =~ /\:/)
            fields = eui.split(':')
            if (fields.length != 6 && fields.length != 8)
                raise ValidationError, "#{eui} is invalid (unrecognized formatting)."
            end
            fields.each {|x| raise ValidationError, "#{eui} is invalid (missing characters)." if (x.length != 2)}
        elsif (eui =~ /\./)
            fields = eui.split('.')
            if (fields.length != 3 && fields.length != 4)
                raise ValidationError, "#{eui} is invalid (unrecognized formatting)."
            end
            fields.each {|x| raise ValidationError, "#{eui} is invalid (missing characters)." if (x.length != 4)}
        else
            raise ValidationError, "#{eui} is invalid (unrecognized formatting)."
        end

    else
        raise ArgumentError, "EUI address should be a String, but was a#{eui.class}."
    end
    return(true)
end
module_function :validate_eui

#===Synopsis
#Validate an IP address. The address should not contain a netmask.
#This method will attempt to auto-detect the IP version
#if not provided, however a slight speed increase is realized if version is provided.
#Raises NetAddr::ValidationError on validation failure.
#
# Example:
# NetAddr.validate_ip_addr('192.168.1.1') => true
# NetAddr.validate_ip_addr('ffff::1', :Version => 6) => true
# NetAddr.validate_ip_addr('::192.168.1.1') => true
# NetAddr.validate_ip_addr(0xFFFFFF) => true
# NetAddr.validate_ip_addr(2**128-1) => true
# NetAddr.validate_ip_addr(2**32-1, :Version => 4) => true
#
#===Arguments
#* ip = IP address as a String or Integer
#* options = Hash with the following keys:
#     :Version -- IP version - Integer (optional)
#
#===Returns:
#* True
#
def validate_ip_addr(ip, options=nil)
    known_args = [:Version]
    version = nil

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Version))
            version = options[:Version]
            if (version != 4 && version != 6)
                raise ArgumentError, ":Version should be 4 or 6, but was '#{version}'."
            end
        end
    end

    if ( ip.kind_of?(String) )
        version = NetAddr.detect_ip_version(ip) if (!version)
        NetAddr.validate_ip_str(ip,version)

    elsif ( ip.kind_of?(Integer) )
        NetAddr.validate_ip_int(ip,version)

    else
        raise ArgumentError, "Integer or String expected for argument 'ip' but " +
                             "#{ip.class} provided." if (!ip.kind_of?(String) && !ip.kind_of?(Integer))
    end

    return(true)
end
module_function :validate_ip_addr

#===Synopsis
#Validate IP Netmask. Version defaults to 4 if not specified.
#Raises NetAddr::ValidationError on validation failure.
#
# Examples:
# NetAddr.validate_ip_netmask('/32') => true
# NetAddr.validate_ip_netmask(32) => true
# NetAddr.validate_ip_netmask(0xffffffff, :Integer => true) => true
#
#===Arguments:
#* netmask = Netmask as a String or Integer
#* options = Hash with the following keys:
#     :Integer -- if true, the provided Netmask is an Integer mask
#     :Version -- IP version - Integer (optional)
#
#===Returns:
#* True
#
def validate_ip_netmask(netmask, options=nil)
    known_args = [:Integer, :Version]
    is_integer = false
    version = 4

    # validate options
    if (options)
        raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash))
        NetAddr.validate_args(options.keys,known_args)

        if (options.has_key?(:Integer) && options[:Integer] == true)
            is_integer = true
        end

        if (options.has_key?(:Version))
            version = options[:Version]
            if (version != 4 && version != 6)
                raise ArgumentError, ":Version should be 4 or 6, but was '#{version}'."
            end
        end
    end

    # validate netmask
    if (netmask.kind_of?(String))
        validate_netmask_str(netmask,version)
    elsif (netmask.kind_of?(Integer) )
        validate_netmask_int(netmask,version,is_integer)
    else
        raise ArgumentError, "Integer or String expected for argument 'netmask' but " +
                             "#{netmask.class} provided." if (!netmask.kind_of?(String) && !netmask.kind_of?(Integer))
    end

    return(true)
end
module_function :validate_ip_netmask

#===Synopsis
#Convert a wildcard IP into a valid CIDR address. Wildcards must always be at
#the end of the address. Any data located after the first wildcard will be lost.
#Shorthand notation is prohibited for IPv6 addresses. 
#IPv6 encoded IPv4 addresses are not currently supported.
#
# Examples:
# NetAddr.wildcard('192.168.*')
# NetAddr.wildcard('192.168.1.*')
# NetAddr.wildcard('fec0:*')
# NetAddr.wildcard('fec0:1:*')
#
#===Arguments:
#* ip = Wildcard IP address as a String
#
#===Returns:
#* CIDR object
#
def wildcard(ip)
    version = 4

    # do operations per version of address
    if (ip =~ /\./ && ip !~ /:/)
        octets = []
        mask = 0

        ip.split('.').each do |x|
            if (x =~ /\*/)
                break
            end
            octets.push(x)
        end

        octets.length.times do
            mask = mask << 8
            mask = mask | 0xff
        end

        until (octets.length == 4)
            octets.push('0')
            mask = mask << 8
        end
        ip = octets.join('.')

    elsif (ip =~ /:/)
        version = 6
        fields = []
        mask = 0

        raise ArgumentError, "IPv6 encoded IPv4 addresses are unsupported." if (ip =~ /\./)
        raise ArgumentError, "Shorthand IPv6 addresses are unsupported." if (ip =~ /::/)

        ip.split(':').each do |x|
            if (x =~ /\*/)
                break
            end
            fields.push(x)
        end

        fields.length.times do
            mask = mask << 16
            mask = mask | 0xffff
        end

        until (fields.length == 8)
            fields.push('0')
            mask = mask << 16
        end
        ip = fields.join(':')
    end

    # make & return cidr
    cidr = cidr_build( version, ip_str_to_int(ip,version), mask )

    return(cidr)
end
module_function :wildcard




end # module NetAddr

__END__

