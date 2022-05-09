#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'



class TestMethods < Test::Unit::TestCase

    def test_i_to_bits
        assert_equal(32, NetAddr.i_to_bits(2**32-1) )
        assert_equal(24, NetAddr.i_to_bits((2**32 - 2**8 ) ) )
        assert_equal(128, NetAddr.i_to_bits(2**128-1) )
        assert_equal(96, NetAddr.i_to_bits((2**128 - 2**32)) )

        assert_raise(ArgumentError){ NetAddr.i_to_bits('1') }
        assert_raise(ArgumentError){ NetAddr.i_to_bits({}) }
        assert_raise(ArgumentError){ NetAddr.i_to_bits('1')}
    end

    def test_i_to_ip
        assert_raise(ArgumentError) {NetAddr.i_to_ip(2**32-1, :test => true)}
        assert_equal('255.255.255.255', NetAddr.i_to_ip(2**32-1) )
        assert_equal('0.0.0.0', NetAddr.i_to_ip(0, :Version => 4) )
        assert_equal('0000:0000:0000:0000:0000:0000:0000:0000', NetAddr.i_to_ip(0, :Version => 6) )
        assert_equal('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff', NetAddr.i_to_ip(2**128-1) )
        assert_equal('0000:0000:0000:0000:0000:0000:ffff:ffff', NetAddr.i_to_ip(2**32-1, :Version => 6) )
        assert_equal('0000:0000:0000:0000:0000:ffff:10.1.0.1', NetAddr.i_to_ip(0xffff0a010001, 
                                                                                      :IPv4Mapped => true,
                                                                                      :Version => 6) )
        assert_raise(ArgumentError){ NetAddr.i_to_ip('1') }
        assert_raise(ArgumentError){ NetAddr.i_to_ip({}) }
        assert_raise(NetAddr::VersionError){ NetAddr.i_to_ip(0xffffffff,:Version => 5) }
        assert_raise(ArgumentError){ NetAddr.i_to_ip('1', :Version => 4) }
    end

    def test_ip_to_i
        assert_raise(ArgumentError) {NetAddr.ip_to_i('255.255.255.255', :test => true)}
        assert_equal(2**128-1, NetAddr.ip_to_i('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff') )
        assert_equal(1, NetAddr.ip_to_i('::1') )
        assert_equal(2**32-1, NetAddr.ip_to_i('255.255.255.255') )
        assert_equal(2**128-1, NetAddr.ip_to_i('ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255') )
        assert_equal(0, NetAddr.ip_to_i('::') )
        assert_equal(2**32-1, NetAddr.ip_to_i('::255.255.255.255') )
        assert_equal(0x0a0a0a0a, NetAddr.ip_to_i('10.10.10.10') )
        assert_equal(2**127+1, NetAddr.ip_to_i('8000::0.0.0.1') )
        assert_equal(0x8080000000000000000080800a0a0a0a, NetAddr.ip_to_i('8080::8080:10.10.10.10') )
        assert_equal(0xffff0a010001, NetAddr.ip_to_i('::ffff:10.1.0.1') )
        assert_equal(2**127+1, NetAddr.ip_to_i('8000::1') )
        assert_equal(1, NetAddr.ip_to_i('::1') )
        assert_equal(2**127, NetAddr.ip_to_i('8000::') )

        assert_raise(ArgumentError){ NetAddr.ip_to_i({}) }
        assert_raise(NetAddr::VersionError){ NetAddr.ip_to_i('192.168.1.1',:Version => 5) }
        assert_raise(ArgumentError){ NetAddr.ip_to_i(0xffffffff,:Version => 4) }
    end

    def test_merge
        assert_raise(ArgumentError){ NetAddr.merge(1) }
        assert_raise(ArgumentError){ NetAddr.merge({}) }

        subs = NetAddr::CIDR.create('10.0.0.0/24').subnet(:Bits => 26, :Objectify => true)
        subs.concat( NetAddr::CIDR.create('10.1.0.0/24').subnet(:Bits => 29, :NumSubnets => 4, :Objectify => true) )
        subs.delete_at(2)
        subs.delete_at(7)
        assert_equal(['10.0.0.0/25', '10.0.0.192/26', '10.1.0.0/27', '10.1.0.64/26', '10.1.0.128/25'], NetAddr.merge(subs) )

        cidr = NetAddr::CIDR.create('fec0::/64')
        subs = cidr.range(1, 8, :Objectify => true)
        subs.concat([NetAddr::CIDR.create('192.168.0.0/27'), NetAddr::CIDR.create('192.168.0.32/27')])
        assert_equal(['192.168.0.0/26', 'fec0::1/128', 'fec0::2/127', 'fec0::4/126', 'fec0::8/128',], NetAddr.merge(subs, :Short => true) )

        subs = []
        NetAddr.range('192.168.35.0','192.168.39.255', 
                      :Inclusive => true, :Bitstep => 32).each {|x| subs.push(NetAddr::CIDR.create("#{x}/27")) }
        assert_equal(['192.168.35.0/24', '192.168.36.0/22'], NetAddr.merge(subs) )

        subs = NetAddr::CIDR.create('10.0.0.0/24').subnet(:Bits => 26, :Objectify => true)
        subs.concat( subs.pop.subnet(:Bits => 27, :Objectify => true) )
        subs.concat( subs.pop.subnet(:Bits => 28, :Objectify => true) )
        subs[5].tag[:test] = true
        merged = NetAddr.merge(subs, :Objectify => true)
        assert_equal('10.0.0.0/24', merged[0].desc)
        assert_equal('10.0.0.240/28', merged[0].tag[:Subnets][5].desc)
        assert(merged[0].tag[:Subnets][5].tag[:test])

        assert_equal(['10.0.0.0/8','192.168.0.0/24'], NetAddr.merge(['10.0.0.0/8', '10.0.0.0/12', '10.0.0.0/24','192.168.0.0/24','192.168.0.64/26']) )

    end

    def test_minimum_size
        assert_raise(ArgumentError) {NetAddr.minimum_size(200, :test => true)}
        assert_equal(24, NetAddr.minimum_size(200))
        assert_equal(96, NetAddr.minimum_size(2**32-1, :Version => 6))
        assert_equal('255.255.255.0', NetAddr.minimum_size(200, :Extended => true))
        assert_equal('255.255.255.224', NetAddr.minimum_size(17, :Extended => true))
        assert_equal(24, NetAddr.minimum_size(200, :Extended => false))
        assert_equal(96, NetAddr.minimum_size(2**32-1, :Version => 6, :Extended => true))
        assert_raise(ArgumentError){ NetAddr.minimum_size({}) }
    end

    def test_netmask_to_i
        assert_raise(ArgumentError) {NetAddr.netmask_to_i('32', :test => true)}
        assert_equal(2**32-1, NetAddr.netmask_to_i('255.255.255.255') )
        assert_equal(2**32-1, NetAddr.netmask_to_i('32') )
        assert_equal(2**32-1, NetAddr.netmask_to_i('/32') )
        assert_equal(2**32-1, NetAddr.netmask_to_i(32) )
        assert_equal(2**128-1, NetAddr.netmask_to_i('128', :Version => 6) )
        assert_equal(2**128-1, NetAddr.netmask_to_i('/128', :Version => 6) )
        assert_equal(2**128-1, NetAddr.netmask_to_i(128, :Version => 6) )
        assert_raise(ArgumentError){ NetAddr.netmask_to_i({}) }
        assert_raise(NetAddr::VersionError){ NetAddr.netmask_to_i('/24',:Version => 5) }
        assert_raise(ArgumentError){ NetAddr.netmask_to_i([], :Version => 4) }
    end

    def test_range
        cidr4_1 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.50/24')
        cidr4_3 = NetAddr::CIDR.create('192.168.1.2/24')
        cidr6_1 = NetAddr::CIDR.create('fec0::/64')
        cidr6_2 = NetAddr::CIDR.create('fec0::32/64')

        assert_raise(ArgumentError) {NetAddr.range(cidr4_1,cidr4_2, :test => true)}
        assert_equal(['192.168.1.1'], NetAddr.range(cidr4_1,cidr4_2, :Limit => 1) )
        assert_equal(['fec0:0000:0000:0000:0000:0000:0000:0001'], NetAddr.range(cidr6_1,cidr6_2, :Limit => 1) )

        list = NetAddr.range('192.168.1.0/24','192.168.1.50/24', :Bitstep => 2)
        assert_equal(25, list.length)
        assert_equal('192.168.1.49', list[24])

        list = NetAddr.range(cidr4_1,cidr4_3, :Objectify => true)
        assert_kind_of(NetAddr::CIDR, list[0])
        assert_equal('192.168.1.1/32', (list[0]).desc)

        assert_raise(ArgumentError){ NetAddr.range(:Limit => 1) }
        assert_raise(NetAddr::VersionError){ NetAddr.range(cidr4_1,cidr6_2) }

        assert_equal(256, NetAddr.range('192.168.0.0', '192.168.0.255', :Size => true, :Inclusive => true) )
    end

    def test_shorten
        assert_equal('fec0::', NetAddr.shorten('fec0:0000:0000:0000:0000:0000:0000:0000') )
        assert_equal('fec0::2:0:0:1', NetAddr.shorten('fec0:0000:0000:0000:0002:0000:0000:0001') )
        assert_equal('fec0::2:0:0:1', NetAddr.shorten('fec0:00:0000:0:02:0000:0:1') )
        assert_equal('fec0::2:2:0:0:1', NetAddr.shorten('fec0:0000:0000:0002:0002:0000:0000:0001') )
        assert_equal('fec0:0:0:1::', NetAddr.shorten('fec0:0000:0000:0001:0000:0000:0000:0000') )
        assert_equal('fec0:1:1:1:1:1:1:1', NetAddr.shorten('fec0:0001:0001:0001:0001:0001:0001:0001') )
        assert_equal('fec0:ffff:ffff:0:ffff:ffff:ffff:ffff', NetAddr.shorten('fec0:ffff:ffff:0000:ffff:ffff:ffff:ffff') )
        assert_equal('fec0:ffff:ffff:ffff:ffff:ffff:ffff:ffff', NetAddr.shorten('fec0:ffff:ffff:ffff:ffff:ffff:ffff:ffff') )
        assert_equal('fec0::', NetAddr.shorten('fec0::') )
        assert_equal('fec0::192.168.1.1', NetAddr.shorten('fec0:0:0:0:0:0:192.168.1.1') )
        assert_raise(ArgumentError){ NetAddr.shorten(1) }   
    end

    def test_sort
        cidr4_1 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.128/25')
        cidr4_3 = NetAddr::CIDR.create('192.168.1.64/26')
        cidr4_4 = NetAddr::CIDR.create('192.168.1.0/30')
        cidr4_5 = '192.168.2.0/24'

        cidr6_1 = NetAddr::CIDR.create('fec0::0/64')
        cidr6_2 = NetAddr::CIDR.create('fec0::0/10')
        cidr6_3 = NetAddr::CIDR.create('fe80::0/10')
        cidr6_4 = 'fe80::0'

        sort1 = NetAddr.sort(['192.168.1.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/30','192.168.2.0/24'])
        assert_equal(['192.168.1.0/24','192.168.1.0/30','192.168.1.64/26','192.168.1.128/25','192.168.2.0/24'], sort1)
        sort1 = NetAddr.sort([cidr4_1,cidr4_2,cidr4_3,cidr4_4,cidr4_5])
        assert_equal([cidr4_1,cidr4_4,cidr4_3,cidr4_2,cidr4_5], sort1)

        sort2 = NetAddr.sort(['fec0::0/64','fec0::0/10','fe80::0/10','fe80::0'])
        assert_equal(['fe80::0/10','fe80::0','fec0::0/10','fec0::0/64'], sort2)
        sort2 = NetAddr.sort([cidr6_1,cidr6_2,cidr6_3,cidr6_4])
        assert_equal([cidr6_3,cidr6_4,cidr6_2,cidr6_1], sort2)

        sort3 = NetAddr.sort([cidr4_1,cidr4_2,cidr4_3,cidr4_4,cidr4_5], :Desc => true)
        assert_equal([cidr4_5,cidr4_2,cidr4_3,cidr4_1,cidr4_4], sort3)
        sort3 = NetAddr.sort(['192.168.1.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/30','192.168.2.0/24'], :Desc => true)
        assert_equal(['192.168.2.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/24','192.168.1.0/30'], sort3)

        sort4 = NetAddr.sort(['192.168.1.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/30','192.168.2.0/24'], :ByMask => true)
        assert_equal(['192.168.1.0/24','192.168.2.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/30'], sort4)
        sort4 = NetAddr.sort([cidr4_1,cidr4_2,cidr4_3,cidr4_4,cidr4_5], :ByMask => true)
        assert_equal([cidr4_1,cidr4_5,cidr4_2,cidr4_3,cidr4_4], sort4)

        sort5 = NetAddr.sort(['192.168.1.0/24','192.168.1.128/25','192.168.1.64/26','192.168.1.0/30','192.168.2.0/24'], :ByMask => true, :Desc => true)
        assert_equal(['192.168.1.0/30','192.168.1.64/26','192.168.1.128/25','192.168.1.0/24','192.168.2.0/24'], sort5)
        sort5 = NetAddr.sort([cidr4_1,cidr4_2,cidr4_3,cidr4_4,cidr4_5], :ByMask => true, :Desc => true)
        assert_equal([cidr4_4,cidr4_3,cidr4_2,cidr4_1,cidr4_5], sort5)
    end

    def test_supernets
        assert_raise(ArgumentError){ NetAddr.supernets(1) }
        assert_raise(ArgumentError){ NetAddr.supernets({}) }

        list4 = ['192.168.1.0', '192.168.1.1', '192.168.1.0/31', '10.1.1.0/24', '10.1.1.32/27']
        list6 = ['fec0::/64', 'fec0::', 'fe80::/32', 'fe80::1']
        assert_equal(['10.1.1.0/24','192.168.1.0/31'], NetAddr.supernets(list4) )
        assert_equal(['fe80:0000:0000:0000:0000:0000:0000:0000/32', 'fec0:0000:0000:0000:0000:0000:0000:0000/64'], NetAddr.supernets(list6) )
        assert_equal(['fe80::/32', 'fec0::/64'], NetAddr.supernets(list6, :Short => true) )

        list4.push( NetAddr::CIDR.create('192.168.0.0/23') )
        list6.push( NetAddr::CIDR.create('fec0::/48') )
        summ = NetAddr.supernets(list4.concat(list6), :Objectify => true)
        assert_equal('192.168.1.0/31', summ[0].tag[:Subnets][0].desc)
    end

    def test_unshorten
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000', NetAddr.unshorten('fec0::') )
        assert_equal('fec0:0000:0000:0000:0002:0000:0000:0001', NetAddr.unshorten('fec0::2:0:0:1') )
        assert_equal('fec0:0000:0000:0000:0002:0000:0000:0001', NetAddr.unshorten('fec0:0:0:0:2:0:0:1') )
        assert_equal('0000:0000:0000:0000:0000:ffff:10.1.0.1', NetAddr.unshorten('::ffff:10.1.0.1') )

        assert_raise(ArgumentError){ NetAddr.unshorten(1) }
    end

    def test_validate_eui
        assert_nothing_raised(NetAddr::ValidationError) {NetAddr.validate_eui('aa-bb-cc-dd-ee-ff')}
        assert_nothing_raised(NetAddr::ValidationError) {NetAddr.validate_eui('aabb.ccdd.eeff') }
        assert_nothing_raised(NetAddr::ValidationError) {NetAddr.validate_eui('aa:bb:cc:dd:ee:ff') }
        assert_nothing_raised(NetAddr::ValidationError) {NetAddr.validate_eui('aabb.ccdd.eeff.1234') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aabb.ccdd.eeff.123') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aabb.ccdd.eeff.12312') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aa-bb-c-dd-ee-ff') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aa:bb:cc:dd:e:ff') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aa:bb:cc:dd:ee:^^') }
        assert_raise(NetAddr::ValidationError){NetAddr.validate_eui('aa:bb:cc:dd:ee:ZZ') }
        assert_raise(ArgumentError){ NetAddr.validate_eui(0xaabbccddeeff) }
        assert_raise(ArgumentError){ NetAddr.validate_eui() }
    end

    def test_validate_ip_addr
        assert_raise(ArgumentError) {NetAddr.validate_ip_addr('192.168.1.0', :test => true)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('192.168.1.0')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('255.255.255.255')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('224.0.0.1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('0.192.0.1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('0.0.0.0')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr(0xff0000)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr(2**32-1)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr(0)}

        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('::')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('ffff::1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('1234:5678:9abc:def0:1234:5678:9abc:def0')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('::1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('ffff::')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('0001::1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('2001:4800::64.39.2.1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('::1.1.1.1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('::192.168.255.0')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr(2**128-1)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('fec0:0:0:0:0:0:192.168.1.1')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_addr('8080::8080:10.10.10.10')}

        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('10.0') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('10.0..0') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('192.168.1.256') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('192..168.1.1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('192.168.1a.255') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('192.168.1.1.1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('ff.ff.ff.ff') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr(2**128-1, :Version => 4) }

        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('ffff::1111::1111') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('abcd:efgh::1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('fffff::1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('fffg::1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('ffff:::0::1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('1:0:0:0:0:0:0:0:1') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('::192.168.256.0') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('::192.168.a3.0') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_addr('::192.168.1.1.0') }

        assert_raise(ArgumentError){ NetAddr.validate_ip_addr({}) }
        assert_raise(ArgumentError){ NetAddr.validate_ip_addr([])}
        assert_raise(ArgumentError){ NetAddr.validate_ip_addr('192.168.1.0', :Version => 5)}

    end

    def test_validate_ip_netmask
        assert_raise(ArgumentError) {NetAddr.validate_ip_netmask('255.255.255.255', :test => true)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask('255.255.255.255')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask('32')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask('/32')}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask(32)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask(0xffffffff, :Integer => true)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask('128', :Version => 6)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask('/128', :Version => 6)}
        assert_nothing_raised(Exception) {NetAddr.validate_ip_netmask(128, :Version => 6)}

        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_netmask('255.192.255.0') }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_netmask(33) }
        assert_raise(NetAddr::ValidationError){ NetAddr.validate_ip_netmask(129, :Version => 6) }

        assert_raise(ArgumentError){ NetAddr.validate_ip_netmask({}) }
        assert_raise(ArgumentError){ NetAddr.validate_ip_netmask([])}
        assert_raise(ArgumentError){ NetAddr.validate_ip_netmask('/24', :Version => 5)}
    end

    def test_wildcard
        cidr = NetAddr.wildcard('192.168.*')
        assert_equal(NetAddr::CIDRv4, cidr.class )
        assert_equal(16, cidr.bits)
        assert_equal('192.168.0.0', cidr.network)

        cidr = NetAddr.wildcard('192.*.1.0')
        assert_equal(8, cidr.bits)
        assert_equal('192.0.0.0', cidr.network)

        cidr = NetAddr.wildcard('fec0:*')
        assert_equal(NetAddr::CIDRv6, cidr.class )
        assert_equal(16, cidr.bits)
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000', cidr.network)

        cidr = NetAddr.wildcard('fec0:1:*')
        assert_equal(32, cidr.bits)
        assert_equal('fec0:0001:0000:0000:0000:0000:0000:0000', cidr.network)

        assert_raise(ArgumentError){NetAddr.wildcard('fec0::*')}
        assert_raise(ArgumentError){NetAddr.wildcard('::ffff:192.168.*')}
    end

end




