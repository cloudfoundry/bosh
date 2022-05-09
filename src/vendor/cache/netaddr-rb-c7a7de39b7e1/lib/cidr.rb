module NetAddr

#=CIDR - Classless Inter-Domain Routing
#
#A class & series of methods for creating and manipulating CIDR network
#addresses. Both IPv4 and IPv6 are supported.
#
#This class accepts a CIDR address, via the CIDR.create method,
#in (x.x.x.x/yy or xxxx::/yy) format for IPv4 and IPv6, or (x.x.x.x/y.y.y.y) for IPv4.
#CIDR.create then creates either a CIDRv4 or CIDRv6 object. An optional tag hash may be 
#provided with each CIDR as a way of adding custom labels.
#
#Upon initialization, the IP version is auto-detected and assigned to the 
#CIDR. The original IP/Netmask passed within the CIDR is stored and then 
#used to determine the confines of the CIDR block. Various properties of the
#CIDR block are accessible via several different methods. There are also
#methods for modifying the CIDR or creating new derivative CIDR's.
#
#An example CIDR object is as follows:
#    NetAddr::CIDR.create('192.168.1.20/24')
#
#This would create a CIDR object (192.168.1.0/24) with the following properties:
#    version = 4
#    base network = 192.168.1.0
#    ip address = 192.168.1.20
#    netmask = /24 (255.255.255.0)
#    size = 256 IP addresses
#    broadcast = 192.168.1.255
#
#You can see how the CIDR object is based around the entire IP space
#defined by the provided IP/Netmask pair, and not necessarily the individual
#IP address itself.
#
class CIDR

private_class_method :new


    # IP version 4 or 6.
    attr_reader :version

    # Hash of custom tags. Should be in the format tag => value.
    attr_reader :tag

    # Integer of either 32 or 128 bits in length, with all bits set to 1
    attr_reader :all_f

    # Integer representing number of bits in this CIDR address
    attr_reader :address_len

    # Hash of custom tags. Should be in the format tag => value.
    #
    # Example:
    #   cidr4.tag[:name] = 'IPv4 CIDR'
    #   puts cidr4.tag[:name]
    #
    def tag=(new_tag)
        if (!new_tag.kind_of? Hash)
            raise ArgumentError, "Expected Hash, but #{new_tag.class} provided."
        end
        @tag = new_tag
    end

#===Synopsis
#Create a new CIDRv4 or CIDRv6 object.
#CIDR formatted netmasks take precedence over extended formatted ones.
#CIDR address defaults to a host network (/32 or /128) if netmask not provided.
#:Mask takes precedence over netmask given within CIDR addresses.
#Version will be auto-detected if not specified.
#
#    NetAddr::CIDR.create('192.168.1.1/24')
#    NetAddr::CIDR.create('192.168.1.1 255.255.255.0')
#    NetAddr::CIDR.create(0x0a010001,:Mask => 0xffffff00:Version => 4)
#    NetAddr::CIDR.create('192.168.1.1',:WildcardMask => ['0.7.0.255', true])
#    NetAddr::CIDR.create('192.168.1.1',:WildcardMask => [0x000007ff, true]
#    NetAddr::CIDR.create('192.168.5.0',:WildcardMask => ['255.248.255.0'])
#    NetAddr::CIDR.create('fec0::/64')
#    NetAddr::CIDR.create('fec0::/64',:Tag => {'interface' => 'g0/1'})
#    NetAddr::CIDR.create('::ffff:192.168.1.1/96')
#
#===Arguments:
#* addr = CIDR address as a String, or an IP address as an Integer
#* options = Hash with the following keys:
#     :Mask -- Integer representing a binary IP Netmask
#     :Version -- IP version - Integer
#     :Tag -- Custom descriptor tag - Hash, tag => value.
#     :WildcardMask -- 2 element Array. First element contains a special bit mask used for
#                      advanced IP pattern matching. The second element should be set to True if this
#                      bit mask is bit flipped.
#
    def CIDR.create(addr, options=nil)
        known_args = [:Mask, :Version, :Tag, :WildcardMask]
        ip, netmask, tag = nil, nil, {}
        version, wildcard_mask ,wildcard_mask_bit_flipped = nil, nil, false
        netmask_int, all_f = nil, nil

        # validate options
        if (options)
            raise ArgumentError, "Hash expected for argument 'options' but " +
                                 "#{options.class} provided." if (!options.kind_of?(Hash) )
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Mask))
                netmask_int = options[:Mask]
                raise ArgumentError, "Expected Integer, but #{netmask_int.class} " +
                                     "provided for option :Mask." if (!netmask_int.kind_of?(Integer))
            end

            if (options.has_key?(:Tag))
                tag = options[:Tag]
                if (!tag.kind_of? Hash)
                    raise ArgumentError, "Expected Hash, but #{tag.class} provided for option :Tag."
                end
            end

            if (options.has_key?(:Version))
                version = options[:Version]
                if (version != 4 && version != 6)
                    raise VersionError, ":Version should be 4 or 6, but was '#{version}'."
                end
            end

            if (options.has_key?(:WildcardMask))
                if (!options[:WildcardMask].kind_of?(Array))
                    raise ArgumentError, "Expected Array, but #{options[:WildcardMask].class} provided for option :WildcardMask."
                end

                wildcard_mask = options[:WildcardMask][0]
                if (!wildcard_mask.kind_of?(String) &&  !wildcard_mask.kind_of?(Integer))
                    raise ArgumentError, "Expected String or Integer, but #{wildcard_mask.class} provided for wildcard mask."
                end
                wildcard_mask_bit_flipped = true if (options[:WildcardMask][1] && options[:WildcardMask][1].kind_of?(TrueClass))
            end
        end

        # validate addr arg & set version if not provided by user
        if (addr.kind_of?(String))
            version = NetAddr.detect_ip_version(addr) if (!version)

            # if extended netmask provided. should only apply to ipv4
            if (version == 4 && addr =~ /.+\s+.+/ )
                addr,netmask = addr.split(' ')
            end

            # if netmask part of ip, then separate ip & mask.
            if (addr =~ /\//)
                ip,netmask = addr.split(/\//)
                if (!ip || !netmask)
                    raise ArgumentError, "CIDR address is improperly formatted. Missing netmask after '/' character." 
                end
            else
                ip = addr
            end

            NetAddr.validate_ip_str(ip,version)
            ip = NetAddr.ip_str_to_int(ip,version)

        elsif (addr.kind_of?(Integer))
            ip = addr
            if (!version)
                if (ip < 2**32)
                    version = 4
                else
                    version = 6
                end
            end
            NetAddr.validate_ip_int(ip,version)

        else
            raise ArgumentError, "String or Integer expected for argument 'addr' but #{addr.class} provided."
        end

        # set all_f based on version
        all_f = 2**32-1
        all_f = 2**128-1 if (version == 6)

        # set netmask. netmask_int takes precedence. set to all_f if no netmask provided
        if (netmask_int)
            NetAddr.validate_netmask_int(netmask_int,version,true)
            netmask = netmask_int
        elsif (netmask)
            NetAddr.validate_netmask_str(netmask,version)
            netmask = NetAddr.netmask_str_to_int(netmask, version)
        else
            netmask = all_f
        end

        # set wildcard mask if not provided, or validate if provided.
        if (wildcard_mask)
            begin
                if (wildcard_mask.kind_of?(String))
                    NetAddr.validate_ip_str(wildcard_mask,version)
                    wildcard_mask = NetAddr.ip_str_to_int(wildcard_mask, version)
                else (wildcard_mask.kind_of?(Integer))
                    NetAddr.validate_ip_int(wildcard_mask,version)
                end
            rescue Exception => error
                raise ValidationError, "Provided wildcard mask failed validation: #{error}"
            end
        end

        return( NetAddr.cidr_build(version, ip, netmask, tag, wildcard_mask, wildcard_mask_bit_flipped) )
    end

# This method performs absolutely no error checking, and is meant to be used only by
# other internal methods for the sake of the speedier creation of CIDR objects.
# Please consider using #create unless you know what you are doing with 100% certainty.
#
#===Arguments:
#* ip - Integer representing an ip address
#* netmask - Integer representing a binary netmask
#* tag - Hash used to append custom tags to CIDR
#* wildcard_mask - Integer representing a binary mask
#* wildcard_mask_bit_flipped - indicates whether or not the wildcard_mask is bit-flipped or not
#
    def initialize(ip, netmask=nil, tag={}, wildcard_mask=nil, wildcard_mask_bit_flipped=false)
        @ip = ip

        if ( self.kind_of?(NetAddr::CIDRv4) )
            @version = 4
            @address_len = 32
        else
            @version = 6
            @address_len = 128
        end
        @all_f = 2**@address_len - 1

        if (netmask)
            @netmask = netmask
        else
            @netmask = 2**@address_len - 1
        end

        @network = (@ip & @netmask)
        @hostmask = @netmask ^ @all_f
        @tag = tag

        if (!wildcard_mask)
            @wildcard_mask = @netmask
        else
            @wildcard_mask = wildcard_mask
            @wildcard_mask = ~@wildcard_mask if (wildcard_mask_bit_flipped)
        end

    end

#===Synopsis
#Compare the sort order of the current CIDR with a provided CIDR and return true
#if current CIDR is less than provided CIDR.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr < '192.168.2.0/24' => true
#
#===Arguments:
#* CIDR address or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def <(cidr)
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        # compare
        lt = false
        lt = true if ( NetAddr.cidr_gt_lt(self,cidr) == -1)

        return(lt)
    end

#===Synopsis
#Compare the sort order of the current CIDR with a provided CIDR and return:
#* 1 if the current CIDR is greater than the provided CIDR
#* 0 if the current CIDR and the provided CIDR are equal (base address and netmask are equal)
#* -1 if the current CIDR is less than the provided CIDR
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr <=> '192.168.2.0/24' => -1
# cidr <=> '192.168.0.0/24' => 1
# cidr <=> '192.168.1.0/24' => 0
#
#===Arguments:
#* CIDR address or NetAddr::CIDR object
#
#===Returns:
#* Integer
#
    def <=>(cidr)
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        # compare
        comparasin = NetAddr.cidr_gt_lt(self,cidr)

        return(comparasin)
    end

#===Synopsis
#Compare the sort order of the current CIDR with a provided CIDR and return true
#if current CIDR is equal to the provided CIDR.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr == '192.168.1.0/24' => true
#
#===Arguments:
#* CIDR address or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def ==(cidr)
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        # compare
        eq = false
        eq = true if ( NetAddr.cidr_gt_lt(self,cidr) == 0)

        return(eq)
    end
    alias :eql? :==

#===Synopsis
#Compare the sort order of the current CIDR with a provided CIDR and return true
#if current CIDR is greater than provided CIDR.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr > '192.168.0.0/24' => true
#
#===Arguments:
#* CIDR address or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def >(cidr)
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        # compare
        gt = false
        gt = true if ( NetAddr.cidr_gt_lt(self,cidr) == 1)

        return(gt)
    end

#===Synopsis
#Provide the IP at the given index of the CIDR.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr4[1] => 192.168.1.1/32
#
#===Arguments:
#* index = Index number as an Integer
#
#===Returns:
#* NetAddr::CIDR object.
#
    def [](index)
        raise ArgumentError, "Integer expected for argument 'index' but " +
                             "#{index.class} provided." if (!index.kind_of?(Integer) )

        addr = @network + index
        if ( (@hostmask | addr) == (@hostmask | @network) )
            addr = NetAddr.cidr_build(@version, addr)
        else
            raise BoundaryError, "Index of #{index} returns IP that is out of " +
                                 "bounds of CIDR network."
        end

        return(addr)
    end

#===Synopsis
#RFC 3531 describes a flexible method for IP subnet allocation from
#a larger parent network. Given the new netmask for subnet allocations from this CIDR,
#provide a list of those subnets arranged by the order in which they should be allocated.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.0.0/16')
# cidr.allocate_rfc3531(21, :Strategy => :centermost) => ["192.168.0.0/21"... "192.168.248.0/21"]
#
#===Arguments:
#* netmask (in bits) for all new subnet allocations
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#    :Strategy -- allocation strategy to use. must be either :centermost or :leftmost (default)
#
#===Returns:
#* Array of Strings or CIDR objects
#
    def allocate_rfc3531(netmask, options=nil)
        short = false
        objectify = false
        strategy = :leftmost

        # validate args
        raise ArgumentError, "Expected Integer for argument (netmask), but #{max.class} received." if ( !netmask.kind_of?(Integer) )
        raise BoundaryError, "Netmask (#{netmask}) is invalid for a version #{self.version} address." if (netmask > @address_len)
        raise BoundaryError, "Netmask (#{netmask}) cannot be less than #{self.bits}." if (netmask < self.bits)
        known_args = [:Objectify, :Short, :Strategy]
        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Strategy))
                strategy = options[:Strategy]
                raise ArgumentError, "Argument :Strategy must be either :leftmost or :centermost." if (strategy != :leftmost && strategy != :centermost)
            end
        end

        subnet_bits = netmask - self.bits
        net_lshift = @address_len - netmask
        new_mask = NetAddr.bits_to_mask(netmask,self.version)
        cidr_list = []
        if (strategy == :leftmost)
            (0..(2**subnet_bits)-1).each do |num|
                mirror = NetAddr.binary_mirror(num, subnet_bits)

                if (!objectify)
                    my_ip_s = NetAddr.ip_int_to_str(@network | (mirror << net_lshift), @version)
                    my_ip_s = NetAddr.shorten(my_ip_s) if (short && @version == 6)
                    cidr_list.push( my_ip_s << '/' << netmask.to_s )
                else
                    cidr_list.push( NetAddr.cidr_build(@version, @network | (mirror << net_lshift), new_mask ) )
                end
            end

        else # :centermost
            round = 1
            bit_count = 1
            lshift = subnet_bits/2
            lshift -= 1 if (subnet_bits & 1 == 0) # if subnet_bits is even number

            unique = {}
            until (bit_count > subnet_bits)
                (0..2**bit_count-1).each do |num|
                    shifted = num << lshift
                    if ( !unique.has_key?(shifted) )
                        if (!objectify)
                            my_ip_s = NetAddr.ip_int_to_str(@network | (shifted << net_lshift), @version)
                            my_ip_s = NetAddr.shorten(my_ip_s) if (short && @version == 6)
                            cidr_list.push( my_ip_s << '/' << netmask.to_s )
                        else
                            cidr_list.push( NetAddr.cidr_build(@version, @network | (shifted << net_lshift), new_mask ) )
                        end
                        unique[shifted] = true
                    end
                end

                lshift -= 1 if (round & 1 == 0) # if even round
                round += 1
                bit_count += 1
            end
        end

        return(cidr_list)
    end

#===Synopsis
#Depending on the IP version of the current CIDR,
#return either an in-addr.arpa. or ip6.arpa. string. The netmask will be used
#to determine the length of the returned string.
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.1/24')
# cidr.arpa => "1.168.192.in-addr.arpa."
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def arpa()

        base = self.ip()
        netmask = self.bits()

        if (@version == 4)
            net = base.split('.')

            if (netmask)
                while (netmask < 32)
                    net.pop
                    netmask = netmask + 8
                end
            end

            arpa = net.reverse.join('.')
            arpa << ".in-addr.arpa."

        elsif (@version == 6)
            fields = base.split(':')
            net = []
            fields.each do |field|
                (field.split("")).each do |x|
                    net.push(x)
                end
            end

            if (netmask)
                while (netmask < 128)
                    net.pop
                    netmask = netmask + 4
                end
            end

            arpa = net.reverse.join('.')
            arpa << ".ip6.arpa."

        end

        return(arpa)
    end

#===Synopsis
#Provide number of bits in Netmask.
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.1/24')
# cidr.bits => 24
#
#===Arguments:
#* none
#
#===Returns:
#* Integer.
#
    def bits()
        return(NetAddr.mask_to_bits(@netmask))
    end

#===Synopsis
#Compare the current CIDR with a provided CIDR and return:
#* 1 if the current CIDR contains (is supernet of) the provided CIDR
#* 0 if the current CIDR and the provided CIDR are equal (base address and netmask are equal)
#* -1 if the current CIDR is contained by (is subnet of) the provided CIDR
#* nil if the two CIDR addresses are unrelated
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.cmp('192.168.1.0/25') => 1
# cidr.cmp('192.168.1.0/24') => 0
# cidr.cmp('192.168.0.0/23') => -1
# cidr.cmp('10.0.0.0/24') => nil
#
#===Arguments:
#* CIDR address or NetAddr::CIDR object
#
#===Returns:
#* Integer or nil
#
    def cmp(cidr)
        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        # compare
        comparasin = NetAddr.cidr_compare(self,cidr)

    return(comparasin)
end

#===Synopsis
#Determines if this CIDR contains (is supernet of)
#the provided CIDR address or NetAddr::CIDR object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr6_2 = NetAddr::CIDR.create('fec0::/96')
# cidr4.contains?('192.168.1.2') => true
# cidr6.contains?(cidr6_2) => true
#
#===Arguments:
#* cidr = CIDR address or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def contains?(cidr)
        contains = false

        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        contains = true if ( NetAddr.cidr_compare(self,cidr) == 1 )

        return(contains)
    end

#===Synopsis
#See to_s
#
    def desc(options=nil)
        to_s(options)
    end

#===Synopsis
#Provide all IP addresses contained within the IP space of this CIDR.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr4.enumerate(:Limit => 4, :Bitstep => 32)
# cidr6.enumerate(:Limit => 4, :Bitstep => 32, :Objectify => true)
#
#===Arguments:
#* options = Hash with the following keys:
#    :Bitstep -- enumerate in X sized steps - Integer
#    :Limit -- limit returned list to X number of items - Integer
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of Strings, or Array of NetAddr::CIDR objects
#
    def enumerate(options=nil)
        known_args = [:Bitstep, :Limit, :Objectify, :Short]
        bitstep = 1
        objectify = false
        limit = nil
        short = false

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Bitstep) )
                bitstep = options[:Bitstep]
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end

            if( options.has_key?(:Limit) )
                limit = options[:Limit]
            end

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end
        end

        list = []
        my_ip = @network
        change_mask = @hostmask | my_ip

        until ( change_mask != (@hostmask | @network) ) 
            if (!objectify)
                my_ip_s = NetAddr.ip_int_to_str(my_ip, @version)
                my_ip_s = NetAddr.shorten(my_ip_s) if (short && @version == 6)
                list.push( my_ip_s )
            else
                list.push( NetAddr.cidr_build(@version,my_ip) )
            end
            my_ip = my_ip + bitstep
            change_mask = @hostmask | my_ip
            if (limit)
                limit = limit - 1
                break if (limit == 0)
            end
        end

        return(list)
    end

#===Synopsis
#Given a list of subnets of the current CIDR, return a new list with any
#holes (missing subnets) filled in.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr4.fill_in(['192.168.1.0/27','192.168.1.64/26','192.168.1.128/25'])
#
#===Arguments:
#* list = Array of CIDR addresses, or Array of NetAddr::CIDR objects
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of CIDR Strings, or an Array of NetAddr::CIDR objects
#

    def fill_in(list, options=nil)
        known_args = [:Objectify, :Short]
        short = false
        objectify = false

        # validate list
        raise ArgumentError, "Array expected for argument 'list' but #{list.class} provided." if (!list.kind_of?(Array) )

        # validate options
        if (options)
            raise ArgumentError, "Hash expected for argument 'options' but " +
                                 "#{options.class} provided." if (!options.kind_of?(Hash) )
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Short) && options[:Short] == true)
                short = true
            end

            if (options.has_key?(:Objectify) && options[:Objectify] == true)
                objectify = true
            end
        end

        # validate each cidr and store in cidr_list
        cidr_list = []
        list.each do |obj|
            if (!obj.kind_of?(NetAddr::CIDR))
                begin
                    obj = NetAddr::CIDR.create(obj)
                rescue Exception => error
                    aise ArgumentError, "A provided CIDR raised the following " +
                                        "errors: #{error}"
                end
            end

            if (!obj.version == self.version)
                raise VersionError, "#{obj.desc(:Short => true)} is not a version #{self.version} address."
            end

            # make sure we contain the cidr
            if ( self.contains?(obj) == false )
                raise "#{obj.desc(:Short => true)} does not fit " +
                      "within the bounds of #{self.desc(:Short => true)}."
            end
            cidr_list.push(obj)
        end

        complete_list = NetAddr.cidr_fill_in(self,cidr_list)
        if (!objectify)
            subnets = []
            complete_list.each {|entry| subnets.push(entry.desc(:Short => short))}
            return(subnets)
        else
            return(complete_list)
        end
    end

#===Synopsis
#Provide original IP address passed during initialization.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.1/24')
# cidr.ip => "192.168.1.1"
#
#===Arguments:
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR object
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def ip(options=nil)
        known_args = [:Objectify, :Short]
        objectify = false
        short = false

        if (options)
            if (!options.kind_of?(Hash))
                raise ArgumentError, "Expected Hash, but " +
                                     "#{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end
        end


        if (!objectify)
            ip = NetAddr.ip_int_to_str(@ip, @version)
            ip = NetAddr.shorten(ip) if (short && @version == 6)
        else
            ip = NetAddr.cidr_build(@version,@ip)
        end

        return(ip)
    end

#===Synopsis
#Determines if this CIDR is contained within (is subnet of)
#the provided CIDR address or NetAddr::CIDR object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr4.is_contained?('192.168.0.0/23')
#
#===Arguments:
#* cidr = CIDR address or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def is_contained?(cidr)
        is_contained = false

        if (!cidr.kind_of?(NetAddr::CIDR))
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        if (cidr.version != @version)
            raise VersionError, "Attempted to compare a version #{cidr.version} CIDR " +
                                 "with a version #{@version} CIDR."
        end

        network = cidr.to_i(:network)
        netmask = cidr.to_i(:netmask)
        hostmask = cidr.to_i(:hostmask)

        is_contained = true if ( NetAddr.cidr_compare(self,cidr) == -1 )

        return(is_contained)
    end

#===Synopsis
#Provide last IP address in this CIDR object.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.last => "192.168.1.255"
#
#===Arguments:
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR object
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def last(options=nil)
        known_args = [:Objectify, :Short]
        objectify = false
        short = false

        if (options)
            if (!options.kind_of?(Hash))
                raise ArgumentError, "Expected Hash, but " +
                                     "#{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end

        end

        ip_int = @network | @hostmask
        if (!objectify)
            ip = NetAddr.ip_int_to_str(ip_int, @version)
            ip = NetAddr.shorten(ip) if (short && !objectify && @version == 6)
        else
            ip = NetAddr.cidr_build(@version,ip_int)
        end

        return(ip)
    end

#===Synopsis
#Given an IP address (or if a NetAddr::CIDR object, then the original IP of that object), determine
#if it falls within the range of addresses resulting from the combination of the 
#IP and Wildcard Mask of this CIDR.
#
# Example:
# cidr4 = NetAddr.CIDRv4.create('10.0.0.0', :WildcardMask => ['0.7.0.255', true])
# cidr4.matches?('10.0.0.22') -> true
# cidr4.matches?('10.8.0.1') -> false
# cidr4.matches?('10.1.0.1') -> true
# cidr4.matches?('10.0.1.22') -> false
#
#===Arguments:
#* ip = IP address as a String or a CIDR object
#
#===Returns:
#* True or False
#
    def matches?(ip)
        ip_int = nil
        if (!ip.kind_of?(NetAddr::CIDR))
            begin
                ip_int = NetAddr.ip_to_i(ip, :Version => @version)
            rescue NetAddr::ValidationError
                raise NetAddr::ValidationError, "Provided IP must be a valid IPv#{@version} address."
            end
        else
            raise NetAddr::ValidationError, "Provided CIDR must be of type #{self.class}" if (ip.class != self.class)
            ip_int = ip.to_i(:ip)
        end

        return(true) if (@ip & @wildcard_mask == ip_int & @wildcard_mask)
        return(false)
    end

#===Synopsis
#Assuming this CIDR is a valid multicast address (224.0.0.0/4 for IPv4 
#and ff00::/8 for IPv6), return its ethernet MAC address (EUI-48) mapping.
#MAC address is based on original IP address passed during initialization.
#
# Example:
# mcast = NetAddr::CIDR.create('224.0.0.6')
# mcast.multicast_mac.address
#
#===Arguments:
#* options = Hash with the following keys:
#    :Objectify -- if true, return EUI objects
#
#===Returns:
#* String or NetAddr::EUI48 object
#
    def multicast_mac(options=nil)
        known_args = [:Objectify]
        objectify = false

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Objectify) && options[:Objectify] == true)
                objectify = true
            end
        end

        if (@version == 4)
            if (@ip & 0xf0000000 == 0xe0000000)
                # map low order 23-bits of ip to 01:00:5e:00:00:00
                mac = @ip & 0x007fffff | 0x01005e000000
            else
                raise ValidationError, "#{self.ip} is not a valid multicast address. IPv4 multicast " +
                      "addresses should be in the range 224.0.0.0/4."
            end
        else
            if (@ip & (0xff << 120) == 0xff << 120)
                # map low order 32-bits of ip to 33:33:00:00:00:00
                mac = @ip & (2**32-1) | 0x333300000000
            else
                raise ValidationError, "#{self.ip} is not a valid multicast address. IPv6 multicast " +
                      "addresses should be in the range ff00::/8."
            end
        end

        eui = NetAddr::EUI48.new(mac)
        eui = eui.address if (!objectify)

        return(eui)
    end

#===Synopsis
#Provide netmask in CIDR format (/yy).
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.netmask => "/24"
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def netmask()
        bits = NetAddr.mask_to_bits(@netmask)
        return("/#{bits}")
    end

#===Synopsis
#Provide base network address.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.network => "192.168.1.0"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Objectify -- if true, return NetAddr::CIDR object
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def network(options=nil)
        known_args = [:Objectify, :Short]
        objectify = false
        short = false

        if (options)
            if (!options.kind_of?(Hash))
                raise ArgumentError, "Expected Hash, but " +
                                     "#{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end
        end


        if (!objectify)
            ip = NetAddr.ip_int_to_str(@network, @version)
            ip = NetAddr.shorten(ip) if (short && @version == 6)
        else
            ip = NetAddr.cidr_build(@version,@network)
        end

        return(ip)
    end

    alias :base :network
    alias :first :network

#===Synopsis
#Provide the next IP following the last available IP within this CIDR object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr4.next_subnet()
# cidr6.next_subnet(:Short => true)}
#
#===Arguments:
#* options = Hash with the following keys:
#     :Bitstep -- step in X sized steps - Integer
#     :Objectify -- if true, return NetAddr::CIDR object
#     :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def next_ip(options=nil)
        known_args = [:Bitstep, :Objectify, :Short]
        bitstep = 1
        objectify = false
        short = false

        if (options)
            if (!options.kind_of?(Hash))
                raise ArgumentError, "Expected Hash, but " +
                                     "#{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Bitstep) )
                bitstep = options[:Bitstep]
            end

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end
        end

        next_ip = @network + @hostmask + bitstep

        if (next_ip > @all_f)
            raise BoundaryError, "Returned IP is out of bounds for IPv#{@version}."
        end


        if (!objectify)
            next_ip = NetAddr.ip_int_to_str(next_ip, @version)
            next_ip = NetAddr.shorten(next_ip) if (short && @version == 6)
        else
            next_ip = NetAddr.cidr_build(@version,next_ip)
        end

        return(next_ip)
    end

#===Synopsis
#Provide the next subnet following this CIDR object. The next subnet will
#be of the same size as the current CIDR object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr4.next_subnet()
# cidr6.next_subnet(:Short => true) 
#
#===Arguments:
#* options = Hash with the following keys:
#    :Bitstep -- step in X sized steps. - Integer
#    :Objectify -- if true, return NetAddr::CIDR object
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def next_subnet(options=nil)
        known_args = [:Bitstep, :Objectify, :Short]
        bitstep = 1
        objectify = false
        short = false

        if (options)
            if (!options.kind_of?(Hash))
                raise ArgumentError, "Expected Hash, but " +
                                     "#{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Bitstep) )
                bitstep = options[:Bitstep]
            end

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end
        end

        bitstep = bitstep * (2**(@address_len - self.bits) )
        next_sub = @network + bitstep

        if (next_sub > @all_f)
            raise BoundaryError, "Returned subnet is out of bounds for IPv#{@version}."
        end

        if (!objectify)
            next_sub = NetAddr.ip_int_to_str(next_sub, @version)
            next_sub = NetAddr.shorten(next_sub) if (short && @version == 6)        
            next_sub = next_sub << "/" << self.bits.to_s
        else
            next_sub = NetAddr.cidr_build(@version,next_sub,self.to_i(:netmask))
        end

        return(next_sub)
    end

#===Synopsis
#Provide the nth IP within this object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr4.nth(1)
# cidr4.nth(1, :Objectify => true)
#
#===Arguments:
#* index = Index number as an Integer
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String or NetAddr::CIDR object.
#
    def nth(index, options=nil)
        known_args = [:Objectify, :Short]
        objectify = false
        short = false

        # validate list
        raise ArgumentError, "Integer expected for argument 'index' but " +
                             "#{index.class} provided." if (!index.kind_of?(Integer) )

        # validate options
        if (options)     
            raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash) )
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                    objectify = true
            end
        end

        my_ip = @network + index
        if ( (@hostmask | my_ip) == (@hostmask | @network) )

            if (!objectify)
                my_ip = NetAddr.ip_int_to_str(my_ip, @version)
                my_ip = NetAddr.shorten(my_ip) if (short && @version == 6)
            else
                my_ip = NetAddr.cidr_build(@version,my_ip)
             end

        else
            raise BoundaryError, "Index of #{index} returns IP that is out of " +
                                 "bounds of CIDR network."
        end

        return(my_ip)
    end

#===Synopsis
#Given a set of index numbers for this CIDR, return all IP addresses within the
#CIDR that are between them (inclusive). If an upper bound is not provided, then
#all addresses from the lower bound up will be returned.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr4.range(0, 1)
# cidr4.range(0, 1, :Objectify => true)
# cidr4.range(0, nil, :Objectify => true)
#
#===Arguments:
#* lower = Lower range boundary index as an Integer
#* upper = Upper range boundary index as an Integer
#* options = Hash with the following keys:
#    :Bitstep -- enumerate in X sized steps - Integer
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of Strings, or Array of NetAddr::CIDR objects
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
    def range(lower, upper=nil, options=nil)
        known_args = [:Bitstep, :Objectify, :Short]
        objectify = false
        short = false
        bitstep = 1

        # validate indexes
        raise ArgumentError, "Integer expected for argument 'lower' " +
                             "but #{lower.class} provided." if (!lower.kind_of?(Integer))

        raise ArgumentError, "Integer expected for argument 'upper' " +
                             "but #{upper.class} provided." if (upper && !upper.kind_of?(Integer))

        upper = @hostmask if (upper.nil?)
        indexes = [lower,upper]
        indexes.sort!
        if ( (indexes[0] < 0) || (indexes[0] > self.size) )
            raise BoundaryError, "Index #{indexes[0]} is out of bounds for this CIDR."
        end

        if (indexes[1] >= self.size)
            raise BoundaryError, "Index #{indexes[1]} is out of bounds for this CIDR."
        end

        # validate options
        if (options)
            raise ArgumentError, "Hash expected for argument 'options' but #{options.class} provided." if (!options.kind_of?(Hash) )
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end

            if( options.has_key?(:Bitstep) )
                bitstep = options[:Bitstep]
            end
        end

        # make range
        start_ip = @network + indexes[0]
        end_ip = @network + indexes[1]
        my_ip = start_ip
        list = []
        until (my_ip > end_ip)
            if (!objectify)
                ip = NetAddr.ip_int_to_str(my_ip, @version)
                ip = NetAddr.shorten(ip) if (short && @version == 6)
            else
                ip = NetAddr.cidr_build(@version,my_ip)
            end

            list.push(ip)
            my_ip += bitstep
        end

        return(list)
    end

#===Synopsis
#Given a single subnet of the current CIDR, provide the remainder of
#the subnets. For example if the original CIDR is 192.168.0.0/24 and you
#provide 192.168.0.64/26 as the portion to exclude, then 192.168.0.0/26,
#and 192.168.0.128/25 will be returned as the remainders.
#
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr4.remainder('192.168.1.32/27')
# cidr4.remainder('192.168.1.32/27', :Objectify => true)
#
#===Arguments:
#* addr = CIDR address or NetAddr::CIDR object
#* options = Hash with the following keys:
#    :Objectify -- if true, return NetAddr::CIDR objects 
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of Strings, or Array of NetAddr::CIDR objects
#
    def remainder(addr, options=nil)
        known_args = [:Objectify, :Short]
        short = nil
        objectify = nil

        # validate options
        if (options)
            raise ArgumentError, "Hash expected for argument 'options' but " +
                                 "#{options.class} provided." if (!options.kind_of?(Hash) )
            NetAddr.validate_args(options.keys,known_args)

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end
        end

        if ( !addr.kind_of?(NetAddr::CIDR) )
            begin
                addr = NetAddr::CIDR.create(addr)
            rescue Exception => error
                raise ArgumentError, "Argument 'addr' raised the following " +
                                     "errors: #{error}"
            end
        end


        # make sure 'addr' is the same ip version
        if ( addr.version != @version )
            raise VersionError, "#{addr.desc(:Short => true)} is of a different " +
                                "IP version than #{self.desc(:Short => true)}."
        end

        # make sure we contain 'to_exclude'
        if ( self.contains?(addr) != true )
            raise BoundaryError, "#{addr.desc(:Short => true)} does not fit " +
                                 "within the bounds of #{self.desc(:Short => true)}."
        end

        # split this cidr in half & see which half 'to_exclude'
        # belongs in. take that half & repeat the process. every time
        # we repeat, store the non-matching half
        new_mask = self.bits + 1
        lower_network = self.to_i(:network)
        upper_network = self.to_i(:network) + 2**(@address_len - new_mask)

        new_subnets = []
        until(new_mask > addr.bits)
            if (addr.to_i(:network) < upper_network)
                match = lower_network
                non_match = upper_network
            else
                match = upper_network
                non_match = lower_network
            end

            if (!objectify)
                non_match = NetAddr.ip_int_to_str(non_match, @version)
                non_match = NetAddr.shorten(non_match) if (short && @version == 6)
                new_subnets.unshift("#{non_match}/#{new_mask}")
            else
                new_subnets.unshift( NetAddr.cidr_build(@version, non_match, NetAddr.bits_to_mask(new_mask,version) ) )
            end

            new_mask = new_mask + 1
            lower_network = match
            upper_network = match + 2**(@address_len - new_mask)
        end

        return(new_subnets)
    end

#===Synopsis
#Resize the CIDR by changing the size of the Netmask. 
#Return the resulting CIDR as a new object.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# new_cidr = cidr4.resize(23)
#
#===Arguments:
#* bits = Netmask as an Integer
#
#===Returns:
#* NetAddr::CIDR object
#
    def resize(bits)
        raise ArgumentError, "Integer or Hash expected, but " +
                             "#{bits.class} provided." if (!bits.kind_of?(Integer))

        NetAddr.validate_ip_netmask(bits, :Version => @version)
        netmask = NetAddr.bits_to_mask(bits, @version)
        network = @network & netmask

        return( NetAddr.cidr_build(@version, network, netmask) )
    end

#===Synopsis
#Resize the current CIDR by changing the size of the Netmask. The original IP
#passed during initialization will be set to the base network address if
#it no longer falls within the bounds of the CIDR.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr4.resize!(23)
#
#===Arguments:
#* bits = Netmask as an Integer
#
#===Returns:
#* True
#
    def resize!(bits)
        raise ArgumentError, "Integer or Hash expected, but " +
                                 "#{bits.class} provided." if (!bits.kind_of?(Integer))

        NetAddr.validate_ip_netmask(bits, :Version => @version)
        netmask = NetAddr.netmask_to_i(bits, :Version => @version)

        @netmask = netmask
        @network = @network & netmask
        @hostmask = @netmask ^ @all_f

        # check @ip
        if ((@ip & @netmask) != (@network))
            @ip = @network
        end

        return(true)
    end

#===Synopsis
#Set the wildcard mask. Wildcard masks are typically used for matching
#entries in an access-list.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr4.set_wildcard_mask('0.0.0.255', true)
# cidr4.set_wildcard_mask('255.255.255.0')
#
#===Arguments:
#* mask = wildcard mask as a String or Integer
#* bit_flipped = if set True then the wildcard mask is interpereted as bit-flipped.
#
#===Returns:
#* nil
#
    def set_wildcard_mask(mask, bit_flipped=false)
        netmask_int = nil
        if (mask.kind_of?(Integer))
            NetAddr.validate_ip_int(mask,@version)
            netmask_int = mask
        else
            begin
                NetAddr.validate_ip_str(mask,@version)
                netmask_int = NetAddr.ip_str_to_int(mask, @version)
            rescue NetAddr::ValidationError
                raise NetAddr::ValidationError, "Wildcard Mask must be a valid IPv#{@version} address."
            end
        end
        netmask_int = ~netmask_int if (bit_flipped)
        @wildcard_mask = netmask_int

        return(nil)
    end

#===Synopsis
#Provide number of IP addresses within this CIDR.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.size => 256
#
#===Arguments:
#* none
#
#===Returns:
#* Integer
#
    def size()
        return(@hostmask + 1)
    end

#===Synopsis
#Create subnets for this CIDR. There are 2 ways to create subnets:
#   * By providing the netmask (in bits) of the new subnets with :Bits.
#   * By providing the number of IP addresses needed in the new subnets with :IPCount
#
#:NumSubnets is used to determine how the CIDR is subnetted. For example, if I request
#the following operation:
#
# NetAddr::CIDR.create('192.168.1.0/24').subnet(:Bits => 26, :NumSubnets => 1)
#
#then I would get back the first /26 subnet of 192.168.1.0/24 and the remainder of the IP
#space as summary CIDR addresses (e.g. 192.168.1.0/26, 192.168.1.64/26, and 192.168.1.128/25).
#If I were to perform the same operation without the :NumSubnets directive, then 192.168.1.0/24
#will be fully subnetted into X number of /26 subnets (e.g. 192.168.1.0/26, 192.168.1.64/26, 
#192.168.1.128/26, and 192.168.1.192/26). 
#
#If neither :Bits nor :IPCount is provided, then the current CIDR will be split in half.
#If both :Bits and :IPCount are provided, then :Bits takes precedence.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr4.subnet(:Bits => 28, :NumSubnets => 3)
# cidr4.subnet(:IPCount => 19)
# cidr4.subnet(:Bits => 28)
# cidr6.subnet(:Bits => 67, :NumSubnets => 4, :Short => true)
#
#===Arguments:
#* options = Hash with the following keys:
#    :Bits --  Netmask (in bits) of new subnets - Integer
#    :IPCount -- Minimum number of IP's that new subnets should contain - Integer
#    :NumSubnets -- Number of X sized subnets to return - Integer
#    :Objectify -- if true, return NetAddr::CIDR objects
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* Array of Strings, or Array of NetAddr::CIDR objects
#
    def subnet(options=nil)
        known_args = [:Bits, :IPCount, :NumSubnets, :Objectify, :Short]
        my_network = self.to_i(:network)
        my_mask = self.bits
        subnet_bits = my_mask + 1
        min_count = nil 
        objectify = false
        short = false

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if ( options.has_key?(:IPCount) )
                subnet_bits = NetAddr.ip_count_to_size(options[:IPCount], @version)
            end

            if ( options.has_key?(:Bits) )
                subnet_bits = options[:Bits]
            end

            if ( options.has_key?(:NumSubnets) )
                num_subnets = options[:NumSubnets]
            end

            if( options.has_key?(:Short) && options[:Short] == true )
                short = true
            end

            if( options.has_key?(:Objectify) && options[:Objectify] == true )
                objectify = true
            end

        end

        # get number of subnets possible with the requested subnet_bits
        num_avail = 2**(subnet_bits - my_mask)

        # get the number of bits in the next supernet and
        # make sure num_subnets is a power of 2
        bits_needed = 1
        num_subnets = num_avail if (!num_subnets)
        until (2**bits_needed >= num_subnets)
            bits_needed += 1
        end
        num_subnets = 2**bits_needed
        next_supernet_bits = subnet_bits - bits_needed


        # make sure subnet isnt bigger than available bits
        if (subnet_bits > @address_len)
            raise BoundaryError, "Requested subnet (#{subnet_bits}) does not fit " +
                  "within the bounds of IPv#{@version}."
        end

        # make sure subnet is larger than mymask
        if (subnet_bits < my_mask)
            raise BoundaryError, "Requested subnet (#{subnet_bits}) is too large for " +
                  "current CIDR space."
        end

        # make sure MinCount is smaller than available subnets
        if (num_subnets > num_avail)
            raise "Requested subnet count (#{num_subnets}) exceeds subnets " +
                  "available for allocation (#{num_avail})."
        end

        # list all 'subnet_bits' sized subnets of this cidr block
        # with a limit of num_subnets
        bitstep = 2**(@address_len - subnet_bits)
        subnets = self.enumerate(:Bitstep => bitstep, :Limit => num_subnets, :Objectify => true)

        # save our subnets
        new_subnets = []
        subnets.each do |subnet|
            if (!objectify)
                if (short && @version == 6)
                    new_subnets.push("#{subnet.network(:Short => true)}/#{subnet_bits}")
                else
                    new_subnets.push("#{subnet.network}/#{subnet_bits}")
                end
            else
                new_subnets.push( NetAddr.cidr_build(@version, subnet.to_i(:network), NetAddr.bits_to_mask(subnet_bits,version) ) )
            end
        end

        # now go through the rest of the cidr space and make the rest
        # of the subnets. we want these to be as tightly merged as possible
        next_supernet_bitstep = (bitstep * num_subnets)
        next_supernet_ip = my_network + next_supernet_bitstep
        until (next_supernet_bits == my_mask)
            if (!objectify)
                next_network = NetAddr.ip_int_to_str(next_supernet_ip, @version)
                next_network = NetAddr.shorten(next_network) if (short && @version == 6)
                new_subnets.push("#{next_network}/#{next_supernet_bits}")
            else
                new_subnets.push(NetAddr.cidr_build(@version, next_supernet_ip, NetAddr.bits_to_mask(next_supernet_bits,version) ) )
            end

            next_supernet_bits -= 1
            next_supernet_ip = next_supernet_ip + next_supernet_bitstep
            next_supernet_bitstep = next_supernet_bitstep << 1
        end

        return(new_subnets)
    end

#===Synopsis
#Provide the next subnet following this CIDR object. The next subnet will
#be of the same size as the current CIDR object.
#
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.0/24')
# cidr.succ => 192.168.2.0/24
#
#===Arguments:
#* none
#
#===Returns:
#* NetAddr::CIDR object.
#
    def succ()
        bitstep = 2**(@address_len - self.bits)
        next_sub = @network + bitstep

        if (next_sub > @all_f)
            raise BoundaryError, "Returned subnet is out of bounds for IPv#{@version}."
        end

        next_sub = NetAddr.cidr_build(@version,next_sub,self.to_i(:netmask))

        return(next_sub)
    end

#===Synopsis
#Convert the requested attribute of the CIDR to an Integer.
# Example:
# cidr = NetAddr::CIDR.create('192.168.1.1/24')
# cidr.to_i => 3232235776
# cidr.to_i(:hostmask) => 255
# cidr.to_i(:ip) => 3232235777
# cidr.to_i(:netmask) => 4294967040
# cidr.to_i(:wildcard_mask) => 4294967040
#
#===Arguments:
#* attribute -- attribute of the CIDR to convert to an Integer (:hostmask, :ip, :netmask, :network, or :wildcard_mask).
#
#===Returns:
#* Integer
#
    def to_i(attribute=:network)
        if(attribute == :network)
            return(@network)
        elsif(attribute == :hostmask)
            return(@hostmask)
        elsif(attribute == :ip)
            return(@ip)
        elsif(attribute == :netmask)
            return(@netmask)
        elsif(attribute == :wildcard_mask)
            return(@wildcard_mask)
        else
            raise ArgumentError, "Attribute is unrecognized. Must be :hostmask, :ip, :netmask, :network, or :wildcard_mask."
        end
    end

#===Synopsis
#Returns network/netmask in CIDR format.
#
# Example:
# cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
# cidr6 = NetAddr::CIDR.create('fec0::/64')
# cidr4.desc(:IP => true) => "192.168.1.1/24"
# cidr4.to_s => "192.168.1.0/24"
# cidr6.to_s(:Short => true) => "fec0::/64"
#
#===Arguments:
#* options = Optional hash with the following keys:
#    :IP -- if true, return the original ip/netmask passed during initialization
#    :Short -- if true, return IPv6 addresses in short-hand notation
#
#===Returns:
#* String
#
    def to_s(options=nil)
        known_args = [:IP, :Short]
        short = false
        orig_ip = false

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Short) && options[:Short] == true)
                short = true
            end

            if (options.has_key?(:IP) && options[:IP] == true)
                orig_ip = true
            end
        end

        if (!orig_ip)
            ip = NetAddr.ip_int_to_str(@network, @version)
        else
            ip = NetAddr.ip_int_to_str(@ip, @version)
        end
        ip = NetAddr.shorten(ip) if (short && @version == 6)
        mask = NetAddr.mask_to_bits(@netmask)

        return("#{ip}/#{mask}")
    end

#===Synopsis
#Return the wildcard mask.
#
# Example:
# cidr = NetAddr::CIDR.create('10.1.0.0/24', :WildcardMask => ['0.7.0.255', true])
# cidr.wildcard_mask => "255.248.255.0"
# cidr.wildcard_mask(true) => "0.7.0.255"
#
#===Arguments:
#* bit_flipped = if set True then returned the bit-flipped version of the wildcard mask.
#
#===Returns:
#* String
#
    def wildcard_mask(bit_flipped=false)
        ret_val = nil
        if (!bit_flipped)
            ret_val = NetAddr.ip_int_to_str(@wildcard_mask, @version)
        else
            ret_val = NetAddr.ip_int_to_str(~@wildcard_mask, @version)
        end

        return(ret_val)
    end

end # end class CIDR





# IPv4 CIDR address - Inherits all methods from NetAddr::CIDR. 
# Addresses of this class are composed of a 32-bit address space.
class CIDRv4 < CIDR

    public_class_method :new

# Alias for last
    alias :broadcast :last

#===Synopsis
#Provide IPv4 Hostmask in extended format (y.y.y.y).
#
# Example:
# cidr = NetAddr::CIDR.create('10.1.0.0/24')
# cidr.hostmask_ext => "0.0.0.255"
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def hostmask_ext()
        return(NetAddr.ip_int_to_str(@hostmask, @version))
    end

#===Synopsis
#Provide IPv4 netmask in extended format (y.y.y.y).
#
# Example:
# cidr = NetAddr::CIDR.create('10.1.0.0/24')
# cidr.netmask_ext => "255.255.255.0"
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def netmask_ext()
        return(NetAddr.ip_int_to_str(@netmask, 4))
    end

end # end class CIDRv4








# IPv6 CIDR address - Inherits all methods from NetAddr::CIDR. 
# Addresses of this class are composed of a 128-bit address space.
class CIDRv6 < CIDR
    public_class_method :new

#===Synopsis
#Generate an IPv6 Unique Local CIDR address based on the algorithm described
#in RFC 4193.
#
#From the RFC:
#
# 1) Obtain the current time of day in 64-bit NTP format [NTP].
#
# 2) Obtain an EUI-64 identifier from the system running this
#    algorithm.  If an EUI-64 does not exist, one can be created from
#    a 48-bit MAC address as specified in [ADDARCH].  If an EUI-64
#    cannot be obtained or created, a suitably unique identifier,
#    local to the node, should be used (e.g., system serial number).
#
# 3) Concatenate the time of day with the system-specific identifier
#    in order to create a key.
#
# 4) Compute an SHA-1 digest on the key as specified in [FIPS, SHA1];
#    the resulting value is 160 bits.
#
# 5) Use the least significant 40 bits as the Global ID.
#
# 6) Concatenate FC00::/7, the L bit set to 1, and the 40-bit Global
#    ID to create a Local IPv6 address prefix.
#
# Example:
# eui = NetAddr::EUI.create('aabb.ccdd.eeff')
# NetAddr::CIDRv6.unique_local(eui) => fdb4:3014:e277:0000:0000:0000:0000:0000/48
#
#===Arguments:
#* NetAddr::EUI object
#
#===Returns:
#* CIDRv6 object
#
    def CIDRv6.unique_local(eui)

        if (eui.kind_of?(NetAddr::EUI48) )
            eui = eui.to_eui64.to_s
        elsif (eui.kind_of?(NetAddr::EUI64) )
            eui = eui.to_s
        else
            raise ArgumentError, "Expected NetAddr::EUI object but #{eui.class} received."
        end

        ntp_time = ''

        # get current time (32-bits), convert to 4-byte string, and append to ntp_time
        time = Time.now.to_i
        4.times do
            ntp_time.insert(0, (time & 0xff).chr )
            time = time >> 8
        end

        # create 32-bit fractional, convert to 4-byte string, and append to ntp_time
        fract = rand(2**32-1)
        4.times do
            ntp_time.insert(0, (fract & 0xff).chr )
            fract = fract >> 8
        end

        # create sha1 hash
        pre_hash = ntp_time << eui
        gid = Digest::SHA1.hexdigest(pre_hash).slice!(30..39)
        addr = 'fd' << gid << '00000000000000000000'

        return( NetAddr::CIDRv6.new(addr.to_i(16), 0xffffffffffff00000000000000000000 ) )
    end

end # end class CIDRv6

end # module NetAddr
__END__
