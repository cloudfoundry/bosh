module NetAddr

#=EUI - Extended Unique Identifier
#
#A class & series of methods for creating and manipulating Extended Unique Identifier
#(EUI) addresses. Two types of address formats are supported EUI-48 and EUI-64. The 
#most common use for this class will be to manipulate MAC addresses (which are essentially
#a type of EUI-48 address).
#
#EUI addresses are separated into two parts, the 
#Organizationally Unique Identifier (OUI) and the Extended Identifier (EI). The OUI
#is assigned by the IEEE and is used to identify a particular hardware manufacturer.
#The EI is assigned by the hardware manufacturer as a per device unique address.
#
#Probably the most useful feature of this class, and thus the reason it was created,
#is to help automate certain address assignments within IP. For example, IPv6
#Link Local addresses use MAC addresses for IP auto-assignment and multicast MAC addresses
#are determined based on the multicast IP address.
#
class EUI

private_class_method :new

#===Synopsis
# This method performs absolutely no error checking, and is meant to be used only by
# other internal methods for the sake of the speedier creation of EUI objects.
# Please consider using #create unless you know what you are doing with 100% certainty.
#
# Example:
# NetAddr::EUI48.new('aabbccddeeff')
#
#===Arguments:
#* EUI as a String or Integer. Strings should contain no formatting characters.
#
    def initialize(eui)

        if (eui.kind_of?(Integer))
            @eui_i = eui
            @eui = eui.to_s(16)
            if ( self.kind_of?(NetAddr::EUI48) )
                @eui = '0' * (12 - @eui.length) << @eui if (@eui.length < 12)
            else
                @eui = '0' * (16 - @eui.length) << @eui if (@eui.length < 16)
            end

        elsif(eui.kind_of?(String))
            @eui = eui
            @eui_i = eui.to_i(16)
        else
            raise ArgumentError, "Expected String or Integer, but #{eui.class} provided."
        end

        # set ei & oui
        if ( self.kind_of?(NetAddr::EUI48) )
            @ei = @eui.slice(6..11)
        else
            @ei = @eui.slice(6..15)
        end

        @oui = @eui.slice(0..5)

    end

#===Synopsis
#Create a new EUI48 or EUI64 object.
#
# Example:
# addr = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff')
# addr = NetAddr::EUI.create('aa:bb:cc:dd:ee:ff')
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr = NetAddr::EUI.create('aa-bb-cc-dd-ee-ff-00-01')
#
#===Arguments
#* eui = EUI as a String
#
#===Returns
#* EUI48 or EUI64 object
#
    def EUI.create(eui)
        if (!eui.kind_of? String)
            raise ArgumentError, "Expected String, but #{eui.class} provided."
        end

        # create local copy & validate
        eui = eui.dup
        NetAddr.validate_eui(eui)

        # remove formatting characters
        eui.gsub!(/[\.\:\-]/, '')

        if (eui.length == 12)
            eui = NetAddr::EUI48.new(eui)
        else
            eui = NetAddr::EUI64.new(eui)
        end

        return(eui)
    end

#===Synopsis
# Returns EUI address. The default address format is xxxx.xxxx.xxxx
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.address(:Delimiter => '-') => "aa-bb-cc-dd-ee-ff"
# addr.address(:Delimiter => ':') => "aa:bb:cc:dd:ee:ff"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Delimiter -- delimitation character. valid values are (- : .)
#
#===Returns:
#* String
#
    def address(options=nil)
        known_args = [:Delimiter]
        delimiter = '-'

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Delimiter))
                delimiter = options[:Delimiter]
                delimiter = '-' if (delimiter != ':' && delimiter != '.')
            end
        end

        if (delimiter == '-' || delimiter == ':')
            addr = octets.join(delimiter)
        elsif (delimiter == '.')
            addr = octets.each_slice(2).to_a.map(&:join).join('.')
        end

        return(addr)
    end

#===Synopsis
#Returns Extended Identifier portion of an EUI address (the vendor assigned ID).
#The default address format is xx-xx-xx
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.ei(:Delimiter => '-') => "dd-ee-ff"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Delimiter -- delimitation character. valid values are (-, and :)
#
#===Returns:
#* String
#
    def ei(options=nil)
        known_args = [:Delimiter]
        delimiter = '-'

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Delimiter))
                if (options[:Delimiter] == ':')
                    delimiter = options[:Delimiter]
                end
            end
        end

        if ( self.kind_of?(NetAddr::EUI48) )
            ei = octets[3..5].join(delimiter)
        else
            ei = octets[3..7].join(delimiter)
        end

        return(ei)
    end

#===Synopsis
# Provide an IPv6 Link Local address based on the current EUI address.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.link_local() => "fe80:0000:0000:0000:aabb:ccff:fedd:eeff"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Short -- if true, return IPv6 addresses in short-hand notation
#    :Objectify -- if true, return CIDR objects
#
#===Returns:
#* CIDR address String or an NetAddr::CIDR object
#
    def link_local(options=nil)
        return( self.to_ipv6('fe80::/64', options) )
    end

#===Synopsis
#Returns Organizationally Unique Identifier portion of an EUI address (the vendor ID).
#The default address format is xx-xx-xx.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.oui(:Delimiter => '-') => "aa-bb-cc"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Delimiter -- delimitation character. valid values are (-, and :)
#
#===Returns:
#* String
#
    def oui(options=nil)
        known_args = [:Delimiter]
        delimiter = '-'

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Delimiter))
                if (options[:Delimiter] == ':')
                    delimiter = options[:Delimiter]
                end
            end
        end
        oui = octets[0..2].join(delimiter)

        return(oui)
    end

#===Synopsis
#Returns the EUI as an Integer.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.to_i => 187723572702975
#
#===Arguments:
#* none
#
#===Returns:
#* Integer
#
    def to_i()
        return(@eui_i)
    end

#===Synopsis
# Given a valid IPv6 subnet, return an IPv6 address based on the current EUI.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.to_ipv6('3ffe::/64') => "3ffe:0000:0000:0000:a8bb:ccff:fedd:eeff"
#
#===Arguments:
#* options = Hash with the following fields:
#    :Short -- if true, return IPv6 addresses in short-hand notation
#    :Objectify -- if true, return CIDR objects
#
#===Returns:
#* IPv6 address String or an NetAddr::CIDRv6 object
#
    def to_ipv6(cidr, options=nil)
        known_args = [:Short, :Objectify]
        objectify = false
        short = false

        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "CIDR raised the following errors: #{error}"
            end
        elsif (cidr.kind_of?(NetAddr::CIDRv4)  )
            raise ArgumentError, "Expected CIDRv6, but #{cidr.class} provided."
        end

        if (cidr.bits > 64)
            raise ValidationError, "Prefix length of provided CIDR must be /64 or less but was #{cidr.netmask}."
        end

        if (options)
            if (!options.kind_of? Hash)
                raise ArgumentError, "Expected Hash, but #{options.class} provided."
            end
            NetAddr.validate_args(options.keys,known_args)

            if (options.has_key?(:Objectify) && options[:Objectify] == true)
                objectify = true
            end

            if (options.has_key?(:Short) && options[:Short] == true)
                short = true
            end
        end

        # get integer equiv of addr. conver eui48 to eui64 if needed
        if ( self.kind_of?(NetAddr::EUI48) )
            eui_i = self.to_eui64.to_i
        else
            eui_i = self.to_i
        end
      
        # toggle u/l bit
        eui_i = eui_i ^ 0x0200000000000000

        # create ipv6 address
        ipv6 = cidr.to_i | eui_i

        if (!objectify)
            ipv6 = NetAddr.i_to_ip(ipv6, :Version => 6)
            ipv6 = NetAddr.shorten(ipv6) if (short)
        else
            ipv6 = NetAddr::CIDRv6.new(ipv6)
        end

        return(ipv6)
    end

#===Synopsis
#Returns the EUI as an unformatted String.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.to_s => "aabbccddeeff"
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def to_s()
        return(@eui)
    end

private

#Returns array with each element representing a single octet of the eui.
#
    def octets()
        return(@octets) if (@octets)

        @octets = []
        str = ''
        @eui.each_byte do |chr|
            str = str << chr
            if (str.length == 2)
                @octets.push(str)
                str = ''
            end
        end

        return(@octets)
    end

end



# EUI-48 Address - Inherits all methods from NetAddr::EUI. 
# Addresses of this class have a 24-bit OUI and a 24-bit EI.
class EUI48 < EUI

    public_class_method :new

#===Synopsis
#Return an EUI64 address based on the current EUI48 address.
#
# Example:
# addr = NetAddr::EUI.create('aabb.ccdd.eeff')
# addr.to_eui64 => NetAddr::EUI64
#
#===Arguments:
#* none
#
#===Returns:
#* NetAddr::EUI64 object
#
    def to_eui64()
        eui = @oui + 'fffe' + @ei
        return( NetAddr::EUI64.new(eui.to_i(16)) )
    end

end



# EUI-64 Address - Inherits all methods from NetAddr::EUI. 
# Addresses of this class have a 24-bit OUI and a 40-bit EI.
class EUI64 < EUI
    public_class_method :new
end


end # module NetAddr
__END__
