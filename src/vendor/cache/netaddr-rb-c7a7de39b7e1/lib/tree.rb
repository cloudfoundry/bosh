module NetAddr

#=Tree
#
#A class & series of methods for creating and manipulating IP-based
#heirarchical trees. Both IPv4 and IPv6 are supported.
#
#A sample tree would look like:
# 192.168.1.0/24
#   192.168.1.0/26
#      192.168.1.0/27
#         192.168.1.0/28
#         192.168.1.16/29
#            192.168.1.16/30
#         192.168.1.24/30
#            192.168.1.25/32
#         192.168.1.28/30
#      192.168.1.32/27
#   192.168.1.64/26
#      192.168.1.64/27
#   192.168.1.128/26
#   192.168.1.192/26
#
class Tree

#===Synopsis
#Create a new Tree object.
#
# Example:
# NetAddr::Tree.new()
#
#===Arguments:
#* none
#
    def initialize()
        # root of our ordered IP tree
        @v4_root = NetAddr::CIDRv4.new(0,0,{:Subnets => []})
        @v6_root = NetAddr::CIDRv6.new(0,0,{:Subnets => []})
    end

#===Synopsis
# Add a CIDR address or NetAddr::CIDR object to the tree.
# Example:
# tree.add!('192.168.1.0/24')
# cidr = NetAddr::CIDR.create('192.168.1.0/24', :Tag => {:title => 'test net'}
# tree.add!(cidr)
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* nil
#
    def add!(new)
        # validate object
        if ( !new.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(new)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        else
            cidr = new.dup
        end

        cidr.tag[:Subnets] = []
        add_to_tree(cidr)

        return(nil)
    end

#===Synopsis
# Returns all the ancestors of the provided CIDR addresses.
#
# Example:
# tree.ancestors('192.168.1.0/27')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def ancestors(cidr)
        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        list = []
        parent = find_parent(cidr)
        until (!parent.tag[:Parent])
            list.push( NetAddr.cidr_build(parent.version, parent.to_i(:network), parent.to_i(:netmask)) )
            parent = parent.tag[:Parent]
        end

        return(list)
    end

#===Synopsis
# Returns all the immediate children of the provided CIDR addresses.
#
# Example:
# tree.children('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def children(cidr)
        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        list = []
        me = find_me(cidr)
        if (me)
            me.tag[:Subnets].each do |child|
                list.push( NetAddr.cidr_build(child.version, child.to_i(:network), child.to_i(:netmask)) )
            end
        end

        return(list)
    end

#===Synopsis
# Return all descendants of the provided CIDR address.
#
# Example:
# tree.descendants('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def descendants(cidr)
        list = []

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)
        if (me)
            dump_children(me).each do |x|
                child = x[:CIDR]
                list.push( NetAddr.cidr_build(child.version, child.to_i(:network), child.to_i(:netmask)) )
            end
        end

        return(list)
    end

#===Synopsis
# Remove the provided CIDR address from the tree.
#
# Example:
# tree.remove!('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true on success or false on fail
#
    def delete!(cidr)
        removed = false

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        # find matching
        me = find_me(cidr)

        # remove
        if (me)
            parent = me.tag[:Parent]
            children = me.tag[:Subnets]
            parent.tag[:Subnets].delete(me)
            children.each {|x| add_to_parent(x,parent)}
            removed = true
        end

        return(removed)
    end

#===Synopsis
# Dump the contents of this tree.
#
# Example:
# tree.dump()
#
#===Arguments:
#* none
#
#===Returns:
#* ordered array of hashes with the following fields: 
#    :CIDR => NetAddr::CIDR object
#    :Depth => (depth level in tree)
#
    def dump()
        list = dump_children(@v4_root)
        list.concat( dump_children(@v6_root) )
        list.each {|x| x[:CIDR] =  NetAddr.cidr_build(x[:CIDR].version, x[:CIDR].to_i(:network), x[:CIDR].to_i(:netmask)) }
        return(list)
    end

#===Synopsis
# Has a CIDR address already been added to the tree?
#
# Example:
# tree.exists?('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def exists?(cidr)
        found = false

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        found = true if (find_me(cidr))
        return(found)
    end

#===Synopsis
# Fill in the missing subnets of a particular CIDR.
#
# Example:
# tree.fill_in!('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true or false
#
    def fill_in!(cidr)
        filled = false

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)
        if (me && me.tag[:Subnets].length != 0)
            me.tag[:Subnets] = NetAddr.cidr_fill_in(me, me.tag[:Subnets])
            me.tag[:Subnets].each do |subnet|
                subnet.tag[:Subnets] = [] if (!subnet.tag.has_key?(:Subnets))
            end
            filled = true
        end
        return(filled)
    end

#===Synopsis
# Find and return a CIDR from within the tree.
#
# Example:
# tree.find('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* NetAddr::CIDR object, or nil
#
    def find(cidr)
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)
        if (me)
            me =  NetAddr.cidr_build(me.version, me.to_i(:network), me.to_i(:netmask)) 
        end

        return(me)
    end

#===Synopsis
# Find subnets that are of at least size X. Only subnets that are not themselves 
# subnetted will be returned. :Subnet takes precedence over :IPCount
#
# Example:
# tree.find_space(:IPCount => 16)
#
#===Arguments:
#* Minimum subnet size in bits, or a Hash with the following keys:
#    :Subnet - minimum subnet size in bits for returned subnets
#    :IPCount - minimum IP count per subnet required for returned subnets
#    :Version - restrict results to IPvX
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def find_space(options)
        known_args = [:Subnet, :IPCount, :Version]
        version = nil
        if (options.kind_of? Integer)
            bits4 = options
            bits6 = options
        elsif (options.kind_of? Hash) 
            NetAddr.validate_args(options.keys,known_args)
            if (options.has_key?(:Version))
                version = options[:Version]
                raise "IP version should be 4 or 6, but was #{version}." if (version != 4 && version !=6)
            end

            if (options.has_key?(:Subnet))
                bits4 = options[:Subnet]
                bits6 = options[:Subnet]
            elsif(options.has_key?(:IPCount))
                bits4 = NetAddr.minimum_size(options[:IPCount], :Version => 4)
                bits6 = NetAddr.minimum_size(options[:IPCount], :Version => 6)
            else
                raise "Missing arguments: :Subnet/:IPCount"
            end
        else
            raise "Integer or Hash expected, but #{options.class} provided."
        end

        list = []
        if (!version || version == 4)
            dump_children(@v4_root).each do |entry|
                cidr = entry[:CIDR]
                if ( (cidr.tag[:Subnets].length == 0) && (cidr.bits <= bits4) )
                    list.push(cidr)
                end
            end
        end

        if (!version || version == 6)
            dump_children(@v6_root).each do |entry|
                cidr = entry[:CIDR]
                if ( (cidr.tag[:Subnets].length == 0) && (cidr.bits <= bits6) )
                    list.push(cidr)
                end
            end
        end

        new_list = []
        list.each {|x| new_list.push( NetAddr.cidr_build(x.version, x.to_i(:network), x.to_i(:netmask)) )}

        return(new_list)
    end

#===Synopsis
#Find the longest matching branch of our tree to which a 
#CIDR address belongs. Useful for performing 'routing table' style lookups.
#
# Example:
# tree.longest_match('192.168.1.1')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* NetAddr::CIDR object
#
    def longest_match(cidr)
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin                
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        found = find_me(cidr)
        found = find_parent(cidr) if !found

        return( NetAddr.cidr_build(found.version, found.to_i(:network), found.to_i(:netmask)) )
    end

#===Synopsis
# Remove all subnets of the provided CIDR address.
#
# Example:
# tree.prune!('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true on success or false on fail
#
    def prune!(cidr)
        pruned = false

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)

        if (me)
            me.tag[:Subnets].clear
            pruned = true
        end

        return(pruned)
    end

#===Synopsis
# Remove the provided CIDR address, and all of its subnets from the tree.
#
# Example:
# tree.remove!('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true on success or false on fail
#
    def remove!(cidr)
        removed = false
        found = nil

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)

        if (me)
            parent = me.tag[:Parent]
            parent.tag[:Subnets].delete(me)
            removed = true
        end

        return(removed)
    end

#===Synopsis
# Resize the provided CIDR address.
#
# Example:
# tree.resize!('192.168.1.0/24', 23)
#
#===Arguments:
#* CIDR address as a String or an NetAddr::CIDR object
#* Integer representing the bits of the new netmask
#
#===Returns:
#* true on success or false on fail
#
    def resize!(cidr,bits)
        resized = false

        # validate cidr
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)

        if (me)
            new = me.resize(bits)
            delete!(me)
            add!(new)
            resized = true
        end

        return(resized)
    end

#===Synopsis
# Returns the root of the provided CIDR address.
#
# Example:
# tree.root('192.168.1.32/27')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* NetAddr::CIDR object
#
    def root(cidr)
        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        parent = find_parent(cidr)
        if (parent.tag.has_key?(:Parent)) # if parent is not 0/0
            while(1)
                grandparent = parent.tag[:Parent]
                break if (!grandparent.tag.has_key?(:Parent)) # if grandparent is 0/0
                parent = grandparent
            end
        end

        return( NetAddr.cidr_build(parent.version, parent.to_i(:network), parent.to_i(:netmask)) )
    end

#===Synopsis
# Print the tree as a formatted string.
#
# Example:
# tree.show()
#
#===Arguments:
#* none
#
#===Returns:
#* String
#
    def show()
        printed = "IPv4 Tree\n---------\n"
        list4 = dump_children(@v4_root)
        list6 = dump_children(@v6_root)

        list4.each do |entry|
            cidr = entry[:CIDR]
            depth = entry[:Depth]

            if (depth == 0)
                indent = ""
            else
                indent = " " * (depth*3)
            end

            printed << "#{indent}#{cidr.desc}\n"
        end

        printed << "\n\nIPv6 Tree\n---------\n" if (list6.length != 0)

       list6.each do |entry|
            cidr = entry[:CIDR]
            depth = entry[:Depth]

            if (depth == 0)
                indent = ""
            else
                indent = " " * (depth*3)
            end

            printed << "#{indent}#{cidr.desc(:Short => true)}\n"
        end

        return(printed)
    end

#===Synopsis
# Return list of the sibling CIDRs of the provided CIDR address.
#
# Example:
# tree.siblings('192.168.1.0/27')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def siblings(cidr)
        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        list = []
        find_parent(cidr).tag[:Subnets].each do |entry|
            if (!cidr.cmp(entry))
                list.push( NetAddr.cidr_build(entry.version, entry.to_i(:network), entry.to_i(:netmask)) )
            end
        end

        return(list)
    end

#===Synopsis
# Summarize all subnets of the provided CIDR address. The subnets will be
# placed under the new summary address within the tree.
#
# Example:
# tree.summarize_subnets!('192.168.1.0/24')
#
#===Arguments:
#* String or NetAddr::CIDR object
#
#===Returns:
#* true on success or false on fail
#
    def summarize_subnets!(cidr)
        merged = false

        # validate object
        if ( !cidr.kind_of?(NetAddr::CIDR) )
            begin
                cidr = NetAddr::CIDR.create(cidr)
            rescue Exception => error
                raise ArgumentError, "Provided argument raised the following " +
                                     "errors: #{error}"
            end
        end

        me = find_me(cidr)

        if (me)
            merged = NetAddr.cidr_summarize(me.tag[:Subnets])
            me.tag[:Subnets] = merged
            merged = true
        end

        return(merged)
    end
    alias :merge_subnets! :summarize_subnets!

#===Synopsis
# Return list of the top-level supernets of this tree.
#
# Example:
# tree.supernets()
#
#===Arguments:
#* none
#
#===Returns:
#* Array of NetAddr::CIDR objects
#
    def supernets()
       supernets = []
       @v4_root.tag[:Subnets].each {|x| supernets.push( NetAddr.cidr_build(x.version, x.to_i(:network), x.to_i(:netmask)) )}
       @v6_root.tag[:Subnets].each {|x| supernets.push( NetAddr.cidr_build(x.version, x.to_i(:network), x.to_i(:netmask)) )}
       return (supernets)
    end



    
private

# Add NetStruct object to an array of NetStruct's
#
    def add_to_parent(cidr, parent)
        duplicate = false
        duplicate = true if (NetAddr.cidr_find_in_list(cidr,parent.tag[:Subnets]).kind_of?(Integer))

        if (!duplicate)
        # check parent for subnets of cidr
            new_parent_subs = []
            parent.tag[:Subnets].length.times do
                old_cidr = parent.tag[:Subnets].shift
                cmp = NetAddr.cidr_compare(cidr, old_cidr)
                if (cmp && cmp == 1)
                    old_cidr.tag[:Parent] = cidr
                    cidr.tag[:Subnets].push(old_cidr)
                else
                    new_parent_subs.push(old_cidr)
                end
            end

            cidr.tag[:Parent] = parent
            parent.tag[:Subnets] = new_parent_subs
            parent.tag[:Subnets].push(cidr)
            parent.tag[:Subnets] = NetAddr.cidr_sort(parent.tag[:Subnets])
        end

        return(nil)
    end

# Add CIDR to a Tree
#
    def add_to_tree(cidr,root=nil)
        parent = find_parent(cidr)
        add_to_parent(cidr,parent)

        return(nil)
    end

#  Dump contents of an Array of NetStruct objects
#
    def dump_children(parent,depth=0)
        list = []

        parent.tag[:Subnets].each do |entry|
            list.push({:CIDR => entry, :Depth => depth})

            if (entry.tag[:Subnets].length > 0)
                list.concat( dump_children(entry, (depth+1) ) )
            end
        end

        return(list)
    end

# Find the NetStruct to which a cidr belongs.
#
    def find_me(cidr)
        me = nil
        root = nil
        if (cidr.version == 4)
            root = @v4_root
        else
            root = @v6_root
        end

        # find matching
        parent = find_parent(cidr,root)
        index = NetAddr.cidr_find_in_list(cidr,parent.tag[:Subnets])
        me = parent.tag[:Subnets][index] if (index.kind_of?(Integer))

        return(me)
    end

# Find the parent NetStruct to which a child NetStruct belongs.
#
    def find_parent(cidr,parent=nil)
        if (!parent)
            if (cidr.version == 4)
                parent = @v4_root
            else
                parent = @v6_root
            end
        end
        bit_diff = cidr.bits - parent.bits

        # if bit_diff greater than 1 bit then check if one of the children is the actual parent.
        if (bit_diff > 1 && parent.tag[:Subnets].length != 0)
            list = parent.tag[:Subnets]
            found = NetAddr.cidr_find_in_list(cidr,list)
            if (found.kind_of?(NetAddr::CIDR))
                parent = find_parent(cidr,found)
            end
        end

        return(parent)
    end

end # class Tree

end # module NetAddr
__END__
