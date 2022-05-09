module NetAddr
private

# CIDR METHODS

# create either a CIDRv4 or CIDRv6 object
#
def cidr_build(version, ip, netmask=nil, tag={}, wildcard_mask=nil, wildcard_mask_bit_flipped=false)
     return( NetAddr::CIDRv4.new(ip, netmask, tag, wildcard_mask, wildcard_mask_bit_flipped) ) if (version == 4)
     return( NetAddr::CIDRv6.new(ip, netmask, tag, wildcard_mask, wildcard_mask_bit_flipped) )
end
module_function :cidr_build


# compare 2 CIDR objects
#
#return:
#* 1 if the cidr1 contains cidr2
#* 0 if the cidr1 and cidr2 are equal
#* -1 if cidr1 is a subnet of cidr2
#* nil if the two are unrelated
#
def cidr_compare(cidr1,cidr2)
    comparasin = nil
    if ( cidr1.to_i(:network) == cidr2.to_i(:network) )
        # same network, check netmask
        if (cidr1.to_i(:netmask) == cidr2.to_i(:netmask) )
            comparasin = 0
        elsif(cidr1.to_i(:netmask) < cidr2.to_i(:netmask))
            comparasin = 1
        elsif(cidr1.to_i(:netmask) > cidr2.to_i(:netmask))
            comparasin = -1
        end

    elsif( (cidr2.to_i(:network) | cidr1.to_i(:hostmask)) == (cidr1.to_i(:network) | cidr1.to_i(:hostmask)) )
        # cidr1 contains cidr2
        comparasin = 1

    elsif( (cidr2.to_i(:network) | cidr2.to_i(:hostmask)) == (cidr1.to_i(:network) | cidr2.to_i(:hostmask)) )
        # cidr2 contains cidr1
        comparasin = -1
    end

    return(comparasin)
end
module_function :cidr_compare

# given a pair of CIDRs, determine if first is greater than or less than the second
#
# return 1 if cidr1 > cidr2
# return 0 if cidr1 == cidr2
# return -1 if cidr1 < cidr2
#
def cidr_gt_lt(cidr1,cidr2)
    gt_lt = 1
    if(cidr1.to_i(:network) < cidr2.to_i(:network))
        gt_lt = -1
    elsif (cidr1.to_i(:network) == cidr2.to_i(:network))
        if (cidr1.to_i(:netmask) < cidr2.to_i(:netmask))
            gt_lt = -1
        elsif (cidr1.to_i(:netmask) == cidr2.to_i(:netmask))
            gt_lt = 0
        end
    end

    return(gt_lt)
end
module_function :cidr_gt_lt

#Given a list of subnets of supernet, return a new list with any
#holes (missing subnets) filled in.
#
def cidr_fill_in(supernet,list)
        # sort our cidr's and see what is missing
        complete_list = []
        expected = supernet.to_i(:network)
        all_f = supernet.all_f

        NetAddr.cidr_sort(list).each do |cidr|
            network = cidr.to_i(:network)
            bitstep = (all_f + 1) - cidr.to_i(:netmask)

            if (network > expected) # missing space at beginning of supernet, so fill in the hole
                num_ips_missing = network - expected
                sub_list = cidr_make_subnets_from_base_and_ip_count(supernet,expected,num_ips_missing)
                complete_list.concat(sub_list)
            elsif (network < expected)
                next
            end

            complete_list.push(cidr)
            expected = network + bitstep
        end

        # if expected is not the next subnet, then we're missing subnets
        # at the end of the cidr
        next_sub = supernet.next_subnet(:Objectify => true).to_i(:network)
        if (expected != next_sub)
            num_ips_missing = next_sub - expected
            sub_list = cidr_make_subnets_from_base_and_ip_count(supernet,expected,num_ips_missing)
            complete_list.concat(sub_list)
        end

        return(complete_list)
end
module_function :cidr_fill_in

# evaluate cidr against list of cidrs.
#
# return entry from list if entry is supernet of cidr (first matching entry)
# return index # of entry if entry is a duplicate of cidr
# return nil if no match found
#
def cidr_find_in_list(cidr,list)
    return(nil) if (list.length == 0)

    match = nil
    low = 0
    high = list.length - 1
    index = low + ( (high-low)/2 )
    while ( low <= high)
        cmp = cidr_gt_lt(cidr,list[index])
        if ( cmp == -1 )
            high = index - 1

        elsif ( cmp == 1 )
            if (cidr_compare(cidr,list[index]) == -1)
                match = list[index]
                break
            end
            low = index + 1

        else
            match = index
            break
        end
        index = low + ( (high-low)/2 )
    end
    return(match)
end
module_function :cidr_find_in_list

# Make CIDR addresses from a base addr and an number of ip's to encapsulate.
#
#===Arguments:
#   * cidr
#   * base ip as integer
#   * number of ip's required
#
#===Returns:
#   * array of NetAddr::CIDR objects
#
    def cidr_make_subnets_from_base_and_ip_count(cidr,base_addr,ip_count)
        list = []
        until (ip_count == 0)
            mask = cidr.all_f
            multiplier = 0
            bitstep = 0
            last_addr = base_addr
            done = false
            until (done == true)
                if (bitstep < ip_count && (base_addr & mask == last_addr & mask) )
                    multiplier += 1
                elsif (bitstep > ip_count || (base_addr & mask != last_addr & mask) )
                    multiplier -= 1
                    done = true
                else
                    done = true
                end
                bitstep = 2**multiplier
                mask = cidr.all_f << multiplier & cidr.all_f
                last_addr = base_addr + bitstep - 1
            end

            list.push(NetAddr.cidr_build(cidr.version,base_addr,mask))
            ip_count -= bitstep
            base_addr += bitstep
        end

        return(list)
    end
module_function :cidr_make_subnets_from_base_and_ip_count

# given a list of NetAddr::CIDRs, return them as a sorted list
#
def cidr_sort(list, desc=false)
    # uses simple quicksort algorithm
    sorted_list = []
    if (list.length < 1)
        sorted_list = list
    else
        less_list = []
        greater_list = []
        equal_list = []
        pivot = list[rand(list.length)]
        if (desc)
            list.each do |x|
                if ( pivot.to_i(:network) < x.to_i(:network) )
                    less_list.push(x)
                elsif ( pivot.to_i(:network) > x.to_i(:network) )
                    greater_list.push(x)
                else
                    if ( pivot.to_i(:netmask) < x.to_i(:netmask) )
                        greater_list.push(x)
                    elsif ( pivot.to_i(:netmask) > x.to_i(:netmask) )
                        less_list.push(x)
                    else
                        equal_list.push(x)
                    end
                end
            end
        else
            list.each do |x|
                gt_lt = cidr_gt_lt(pivot,x)
                if (gt_lt == 1)
                    less_list.push(x)
                elsif (gt_lt == -1)
                    greater_list.push(x)
                else
                    equal_list.push(x)
                end
            end
        end

        sorted_list.concat( cidr_sort(less_list, desc) )
        sorted_list.concat(equal_list)
        sorted_list.concat( cidr_sort(greater_list, desc) )
    end

    return(sorted_list)
end
module_function :cidr_sort

# given a list of NetAddr::CIDRs (of the same version) summarize them
#
# return a hash, with the key = summary address and val = array of original cidrs
#
def cidr_summarize(subnet_list)
    all_f = subnet_list[0].all_f
    version = subnet_list[0].version
    subnet_list = cidr_sort(subnet_list)

    # continue summarization attempts until sorted_list stops getting shorter
    sorted_list = subnet_list.dup
    sorted_list_len = sorted_list.length
    while (1)
        summarized_list = []
        until (sorted_list.length == 0)
            cidr = sorted_list.shift
            network, netmask = cidr.to_i(:network), cidr.to_i(:netmask)
            supermask = (netmask << 1) & all_f
            supernet = supermask & network

            if (network == supernet && sorted_list.length > 0)
                # network is lower half of supernet, so see if we have the upper half
                bitstep = (all_f + 1) - netmask
                expected = network + bitstep
                next_cidr = sorted_list.shift
                next_network, next_netmask = next_cidr.to_i(:network), next_cidr.to_i(:netmask)

                if ( (next_network == expected) && (next_netmask == netmask) )
                    # we do indeed have the upper half. store new supernet.
                    summarized_list.push( cidr_build(version,supernet,supermask) )
                else
                    # we do not have the upper half. put next_cidr back into sorted_list
                    # and store only the original network
                    sorted_list.unshift(next_cidr)
                    summarized_list.push(cidr)
                end
            else
                # network is upper half of supernet, so save original network only
                summarized_list.push(cidr)
            end

        end

        sorted_list = summarized_list.dup
        break if (sorted_list.length == sorted_list_len)
        sorted_list_len = sorted_list.length
    end

    # clean up summarized_list
    unique_list = {}
    summarized_list.reverse.each do |supernet|
        next if ( unique_list.has_key?(supernet.desc) )
        # remove duplicates
        unique_list[supernet.desc] = supernet

        # remove any summary blocks that are children of other summary blocks
        index = 0
        until (index >= summarized_list.length)
            subnet = summarized_list[index]
            if (subnet &&  cidr_compare(supernet,subnet) == 1 )
                unique_list.delete(subnet.desc)
            end
            index += 1
        end
    end
    summarized_list = unique_list.values

    # map original blocks to their summaries
    summarized_list.each do |supernet|
        supernet.tag[:Subnets] = []
        index = 0
        until (index >= subnet_list.length)
            subnet = subnet_list[index]
            if (subnet && cidr_compare(supernet,subnet) == 1 )
                subnet_list[index] = nil
                supernet.tag[:Subnets].push(subnet)
            end
            index += 1
        end
    end

    return( NetAddr.cidr_sort(summarized_list) )
end
module_function :cidr_summarize

# given a list of NetAddr::CIDRs (of the same version), return only the 'top level' blocks (i.e. blocks not
# contained by other blocks

def cidr_supernets(subnet_list)
    summary_list = []
    subnet_list = netmask_sort(subnet_list)
    subnet_list.each do |child|
        is_parent = true
        summary_list.each do |parent|
            if (NetAddr.cidr_compare(parent,child) == 1)
                is_parent = false
                parent.tag[:Subnets].push(child)
            end
        end

        if (is_parent)
            child.tag[:Subnets] = []
            summary_list.push(child)
        end
    end

    return(summary_list)
end
module_function :cidr_supernets

# given a list of NetAddr::CIDRs, return them as a sorted (by netmask) list
#
def netmask_sort(list, desc=false)
    # uses simple quicksort algorithm
    sorted_list = []
    if (list.length < 1)
        sorted_list = list
    else
        less_list = []
        greater_list = []
        equal_list = []
        pivot = list[rand(list.length)]
        if (desc)
            list.each do |x|
                if ( pivot.to_i(:netmask) < x.to_i(:netmask) )
                    less_list.push(x)
                elsif ( pivot.to_i(:netmask) > x.to_i(:netmask) )
                    greater_list.push(x)
                else
                    if ( pivot.to_i(:network) < x.to_i(:network) )
                        greater_list.push(x)
                    elsif ( pivot.to_i(:network) > x.to_i(:network) )
                        less_list.push(x)
                    else
                        equal_list.push(x)
                    end
                end
            end
        else
            list.each do |x|
                if ( pivot.to_i(:netmask) < x.to_i(:netmask) )
                    greater_list.push(x)
                elsif ( pivot.to_i(:netmask) > x.to_i(:netmask) )
                    less_list.push(x)
                else
                    if ( pivot.to_i(:network) < x.to_i(:network) )
                        greater_list.push(x)
                    elsif ( pivot.to_i(:network) > x.to_i(:network) )
                        less_list.push(x)
                    else
                        equal_list.push(x)
                    end
                end
            end
        end

        sorted_list.concat( netmask_sort(less_list, desc) )
        sorted_list.concat(equal_list)
        sorted_list.concat( netmask_sort(greater_list, desc) )
    end

    return(sorted_list)
end
module_function :netmask_sort

end # module NetAddr

__END__