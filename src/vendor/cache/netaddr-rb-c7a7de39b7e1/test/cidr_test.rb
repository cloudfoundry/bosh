#!/usr/bin/ruby

#require 'lib/netaddr.rb'
require_relative "../lib/netaddr.rb"
require 'test/unit'



class TestCIDR < Test::Unit::TestCase


    def test_new
        cidr = NetAddr::CIDRv4.new(3232235777, netmask=4294967040, tag={}, wildcard_mask=4294967040)
        assert_equal('192.168.1.0/24', cidr.desc)
        assert_equal('192.168.1.1', cidr.ip)
        assert_equal('255.255.255.0', cidr.wildcard_mask)
    end

    def test_create
        assert_raise(ArgumentError) {NetAddr::CIDR.create('192.168.1.0/24', :test => true)}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('0.0.0.0/0')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.0/24')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.0/24') }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.0 255.255.255.0')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.1') }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.1    ') }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('fec0::/64') }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.1/24 255.255.0.0')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('::/0')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('fec0::1/64')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('fec0::1/64')}
        assert_nothing_raised(Exception){NetAddr::CIDR.create(0x0a0a0a0a, :Mask => 0xffffffff)}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.1', :WildcardMask => ['0.0.7.255', true]) }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('192.168.1.1', :WildcardMask => [0x000007ff, true]) }
        assert_nothing_raised(Exception){NetAddr::CIDR.create('fec0::1', :WildcardMask => ['0000:ffff::ffff', true])}
        assert_nothing_raised(Exception){NetAddr::CIDR.create('fec0::1', :WildcardMask => [0xffff, true])}

        assert_kind_of(NetAddr::CIDRv4, NetAddr::CIDR.create('192.168.1.1 255.255.0.0'))
        assert_kind_of(NetAddr::CIDRv4, NetAddr::CIDR.create('192.168.1.1/24 255.255.0.0'))
        assert_kind_of(NetAddr::CIDRv6, NetAddr::CIDR.create('fec0::1/64'))
        assert_kind_of(NetAddr::CIDRv4, NetAddr::CIDR.create('10.10.10.10/32 255.255.255.0'))
        assert_kind_of(NetAddr::CIDRv4, NetAddr::CIDR.create('10.10.10.10/32', :Mask => 0xffffff00))

        assert_raise(ArgumentError){ NetAddr::CIDR.create(:Version => 4) }
        assert_raise(NetAddr::ValidationError){ NetAddr::CIDR.create('192.168.1.1', :WildcardMask => ['0000:ffff::ffff', true]) }
        assert_raise(NetAddr::ValidationError){ NetAddr::CIDR.create('fec0::1', :WildcardMask => ['0.0.7.255', true]) }

        cidr = NetAddr::CIDRv4.create('192.168.1.1 255.255.0.0')
        assert_equal(16, cidr.bits )

        cidr = NetAddr::CIDRv4.create('192.168.1.1/24 255.255.0.0')
        assert_equal(24, cidr.bits )

        cidr = NetAddr::CIDRv4.create('10.10.10.10/32 255.255.255.0')
        assert_equal(32, cidr.bits )

        cidr = NetAddr::CIDRv4.create('10.10.10.10/32', :Mask => 0xffffff00)
        assert_equal(24, cidr.bits )

        cidr = NetAddr::CIDR.create('fec0::1/64')
        assert_equal(64, cidr.bits )

        assert_raise(ArgumentError){ NetAddr::CIDRv4.create({}) }
        assert_raise(NetAddr::ValidationError){ NetAddr::CIDRv4.create('192.168.1.0 a') }
    end

    def test_comparasins
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')

        assert(cidr4 == '192.168.1.0/24')
        assert(cidr4 > '192.168.0.0/24')
        assert(cidr4 < '192.168.2.0/24')
        assert_equal(0, cidr4 <=> '192.168.1.0/24')
        assert_equal(1, cidr4 <=> '192.168.0.0/24')
        assert_equal(-1, cidr4 <=> '192.168.2.0/24')
    end

    def test_index
        cidr = NetAddr::CIDR.create('192.168.1.0/24')
        assert_equal('192.168.1.1/32', cidr[1].desc)
        assert_equal('192.168.1.255/32', cidr[255].desc)
        assert_raise(NetAddr::BoundaryError){ cidr[256] }
        assert_raise(NetAddr::BoundaryError){ cidr[-1] }
        assert_raise(ArgumentError){ cidr['a'] }
    end

    def test_allocate_allocate_rfc3531
        cidr = NetAddr::CIDR.create('192.168.0.0/16')
        centermost = ["192.168.0.0/21", "192.168.32.0/21", "192.168.64.0/21", "192.168.96.0/21",
                      "192.168.16.0/21", "192.168.48.0/21", "192.168.80.0/21", "192.168.112.0/21",
                      "192.168.128.0/21", "192.168.144.0/21", "192.168.160.0/21", "192.168.176.0/21",
                      "192.168.192.0/21", "192.168.208.0/21", "192.168.224.0/21", "192.168.240.0/21",
                      "192.168.8.0/21", "192.168.24.0/21", "192.168.40.0/21", "192.168.56.0/21", "192.168.72.0/21",
                      "192.168.88.0/21", "192.168.104.0/21", "192.168.120.0/21", "192.168.136.0/21",
                      "192.168.152.0/21", "192.168.168.0/21", "192.168.184.0/21", "192.168.200.0/21",
                      "192.168.216.0/21", "192.168.232.0/21", "192.168.248.0/21"]
        leftmost = ["192.168.0.0/21", "192.168.128.0/21", "192.168.64.0/21", "192.168.192.0/21",
                    "192.168.32.0/21", "192.168.160.0/21", "192.168.96.0/21", "192.168.224.0/21",
                    "192.168.16.0/21", "192.168.144.0/21", "192.168.80.0/21", "192.168.208.0/21",
                    "192.168.48.0/21", "192.168.176.0/21", "192.168.112.0/21", "192.168.240.0/21",
                    "192.168.8.0/21", "192.168.136.0/21", "192.168.72.0/21", "192.168.200.0/21",
                    "192.168.40.0/21", "192.168.168.0/21", "192.168.104.0/21", "192.168.232.0/21",
                    "192.168.24.0/21", "192.168.152.0/21", "192.168.88.0/21", "192.168.216.0/21",
                    "192.168.56.0/21", "192.168.184.0/21", "192.168.120.0/21", "192.168.248.0/21"]

        assert_equal(centermost, cidr.allocate_rfc3531(21, :Strategy => :centermost) )
        assert_equal(leftmost, cidr.allocate_rfc3531(21) )
        assert_equal("192.168.192.0/21", cidr.allocate_rfc3531(21, :Objectify => true)[3].desc )
        assert_equal("192.168.96.0/21", cidr.allocate_rfc3531(21, :Strategy => :centermost, :Objectify => true)[3].desc )
    end

    def test_arpa
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_equal('1.168.192.in-addr.arpa.', cidr4.arpa() )
        assert_equal('0.0.0.0.0.0.0.0.0.0.0.0.0.c.e.f.ip6.arpa.', cidr6.arpa() )
    end

    def test_bits
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')
        assert_equal(24,cidr4.bits() )
        assert_equal(64,cidr6.bits() )
    end

    def test_cmp

        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr6 = NetAddr::CIDR.create('fec0::/64')
        cidr6_2 = NetAddr::CIDR.create('fec0::/96')

        assert_equal(1,cidr4.cmp('192.168.1.0/26') )
        assert_equal(-1,cidr4.cmp('192.168.0.0/23') )
        assert_equal(0,cidr4.cmp('192.168.1.0/24') )
        assert_nil(cidr4.cmp('192.168.2.0/26') )
        assert_equal(1,cidr4.cmp(cidr4_2) )
        assert_equal(1,cidr6.cmp('fec0::/96') )
        assert_equal(-1,cidr6.cmp('fec0::/63') )
        assert_equal(0,cidr6.cmp('fec0::/64') )
        assert_nil(cidr6.cmp('fe80::/64') )
        assert_equal(1,cidr6.cmp(cidr6_2) )

        assert_raise(NetAddr::VersionError) { cidr4.cmp(cidr6_2) }
    end

    def test_contains?

        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr6 = NetAddr::CIDR.create('fec0::/64')
        cidr6_2 = NetAddr::CIDR.create('fec0::/96')

        assert_equal(true,cidr4.contains?('192.168.1.0/26') )
        assert_equal(true,cidr4.contains?(cidr4_2) )
        assert_equal(true,cidr6.contains?(cidr6_2) )
        assert_equal(false,cidr4.contains?('192.168.2.0/26') )
        assert_equal(false,cidr6.contains?('fe80::/96') )

        assert_raise(NetAddr::VersionError) { cidr4.contains?(cidr6_2) }
    end

    def test_desc
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_raise(ArgumentError) {cidr4.desc(:test => true)}
        assert_equal('192.168.1.0/24',cidr4.desc() )
        assert_equal('192.168.1.1/24',cidr4.desc(:IP => true) )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000/64',cidr6.desc() )
        assert_equal('fec0::/64',cidr6.desc(:Short => true) )
    end

    def test_enumerate
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64')

        assert_raise(ArgumentError) {cidr4.enumerate(:test => true)}
        assert_equal(['192.168.1.0', '192.168.1.1'],cidr4.enumerate(:Limit => 2) )
        assert_equal(['fec0:0000:0000:0000:0000:0000:0000:0000'],cidr6.enumerate(:Limit => 1) )
        assert_equal(['fec0::'],cidr6.enumerate(:Limit => 1, :Short => true) )

        enums4 = cidr4.enumerate(:Limit => 2, :Bitstep => 5)
        enums6 = cidr6.enumerate(:Limit => 2, :Bitstep => 5)
        assert_equal('192.168.1.5', enums4[1] )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0005', enums6[1] )

        enums4 = cidr4.enumerate(:Objectify => true,:Limit => 1)
        assert_kind_of(NetAddr::CIDR, enums4[0] )
    end

    def test_fill_in
        cidr = NetAddr::CIDR.create('192.168.1.0/24')
        filled = cidr.fill_in(['192.168.1.0/27','192.168.1.44/30',
                               '192.168.1.64/26','192.168.1.129'])

        assert_equal(['192.168.1.0/27','192.168.1.32/29','192.168.1.40/30',
                      '192.168.1.44/30','192.168.1.48/28','192.168.1.64/26',
                      '192.168.1.128/32','192.168.1.129/32','192.168.1.130/31',
                      '192.168.1.132/30','192.168.1.136/29','192.168.1.144/28',
                      '192.168.1.160/27','192.168.1.192/26'],filled)
    end

    def test_hostmask_ext
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        assert_equal('0.0.0.255',cidr4.hostmask_ext() )
        assert_equal('255.255.255.0',cidr4.netmask_ext() )
    end

    def test_ip
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_raise(ArgumentError) {cidr4.ip(:test => true)}
        assert_equal('192.168.1.1',cidr4.ip() )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0001',cidr6.ip() )
        assert_equal('fec0::1',cidr6.ip(:Short => true) )
    end

    def test_is_contained?

        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr6 = NetAddr::CIDR.create('fec0::/64')
        cidr6_2 = NetAddr::CIDR.create('fec0::/96')

        assert_equal(true,cidr4_2.is_contained?('192.168.1.0/24') )
        assert_equal(true,cidr4_2.is_contained?(cidr4) )
        assert_equal(true,cidr6_2.is_contained?('fec0::/64') )
        assert_equal(true,cidr6_2.is_contained?(cidr6) )
        assert_equal(false,cidr4.is_contained?('192.168.2.0/26') )
        assert_equal(false,cidr6.is_contained?('fe80::/96') )

        assert_raise(NetAddr::VersionError) { cidr4.is_contained?(cidr6_2) }
    end

    def test_last
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_raise(ArgumentError) {cidr4.last(:test => true)}
        assert_equal('192.168.1.255',cidr4.last() )
        assert_equal('fec0:0000:0000:0000:ffff:ffff:ffff:ffff',cidr6.last() )
        assert_equal('fec0::ffff:ffff:ffff:ffff',cidr6.last(:Short => true) )
    end

    def test_matches?
        cidr = NetAddr::CIDR.create('10.0.0.0/24')
        assert(cidr.matches?('10.0.0.22'))
        assert(!cidr.matches?('10.1.1.1'))

        cidr = NetAddr::CIDR.create('10.0.248.0', :WildcardMask => ['255.248.255.0'])
        assert(cidr.matches?('10.1.248.0'))
        assert(!cidr.matches?('10.8.248.0'))

        cidr = NetAddr::CIDR.create('10.0.248.0')
        cidr.set_wildcard_mask('0.7.0.255', true)
        assert(cidr.matches?('10.1.248.0'))
        assert(!cidr.matches?('10.8.248.0'))

        cidr = NetAddr::CIDR.create('127.0.0.0')
        cidr.set_wildcard_mask('0.255.255.255', true)
        assert(cidr.matches?('127.0.0.1'))
        assert(!cidr.matches?('128.0.0.0'))

        cidr = NetAddr::CIDR.create('127.0.0.0', :WildcardMask => ['0.255.255.255', true])
        assert(cidr.matches?('127.0.0.1'))
        assert(!cidr.matches?('128.0.0.0'))

        cidr = NetAddr::CIDR.create('fec0::1')
        cidr.set_wildcard_mask('0000:ffff::ffff', true)
        assert(cidr.matches?('fec0:1::1'))
        assert(!cidr.matches?('fec0:0:1::1'))

        cidr = NetAddr::CIDR.create('fec0::1', :WildcardMask => ['0000:ffff::ffff', true])
        assert(cidr.matches?('fec0:1::1'))
        assert(!cidr.matches?('fec0:0:1::1'))
    end

    def test_mcast
        cidr4 = NetAddr::CIDR.create('224.0.0.1')
        cidr4_2 = NetAddr::CIDR.create('239.255.255.255')
        cidr4_3 = NetAddr::CIDR.create('230.2.3.5')
        cidr4_4 = NetAddr::CIDR.create('235.147.18.23')
        cidr4_5 = NetAddr::CIDR.create('192.168.1.1')
        cidr6 = NetAddr::CIDR.create('ff00::1')
        cidr6_2 = NetAddr::CIDR.create('ffff::1')
        cidr6_3 = NetAddr::CIDR.create('ff00::ffff:ffff')
        cidr6_4 = NetAddr::CIDR.create('ff00::fec0:1234:')
        cidr6_5 = NetAddr::CIDR.create('2001:4800::1')

        assert_raise(ArgumentError) {cidr4.multicast_mac(:test => true)}
        assert_equal('01-00-5e-00-00-01',cidr4.multicast_mac(:Objectify => true).address )
        assert_equal('01-00-5e-7f-ff-ff',cidr4_2.multicast_mac )
        assert_equal('01-00-5e-02-03-05',cidr4_3.multicast_mac )
        assert_equal('01-00-5e-13-12-17',cidr4_4.multicast_mac )

        assert_equal('33-33-00-00-00-01',cidr6.multicast_mac(:Objectify => true).address )
        assert_equal('33-33-00-00-00-01',cidr6_2.multicast_mac )
        assert_equal('33-33-ff-ff-ff-ff',cidr6_3.multicast_mac )
        assert_equal('33-33-fe-c0-12-34',cidr6_4.multicast_mac )

        assert_raise(NetAddr::ValidationError){ cidr4_5.multicast_mac }
        assert_raise(NetAddr::ValidationError){ cidr6_5.multicast_mac }
    end

    def test_netmask
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_equal('/24',cidr4.netmask() )
        assert_equal('/64',cidr6.netmask() )
    end

    def test_netmask_ext
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        assert_equal('255.255.255.0',cidr4.netmask_ext() )
    end

    def test_network
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_raise(ArgumentError) {cidr4.network(:test => true)}
        assert_equal('192.168.1.0',cidr4.network() )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000',cidr6.network() )
        assert_equal('fec0::',cidr6.network(:Short => true) )
    end

    def test_next_ip
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64')

        assert_raise(ArgumentError) {cidr4.next_ip(:test => true)}
        next4 = cidr4.next_ip()
        next6 = cidr6.next_ip()
        assert_equal('192.168.2.0',next4 )
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0000',next6 )

        next6 = cidr6.next_ip(:Short => true)
        assert_equal('fec0:0:0:1::',next6 )

        next4 = cidr4.next_ip(:Bitstep => 2)
        next6 = cidr6.next_ip(:Bitstep => 2)
        assert_equal('192.168.2.1',next4 )
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0001',next6 )

        next4 = cidr4.next_ip(:Objectify => true)
        next6 = cidr6.next_ip(:Objectify => true)
        assert_equal('192.168.2.0/32',next4.desc )
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0000/128',next6.desc )

    end

    def test_next_subnet
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64')

        assert_raise(ArgumentError) {cidr4.next_subnet(:test => true)}
        next4 = cidr4.next_subnet()
        next6 = cidr6.next_subnet()
        assert_equal('192.168.2.0/24',next4 )
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0000/64',next6 )

        next6 = cidr6.next_subnet(:Short => true)
        assert_equal('fec0:0:0:1::/64',next6 )

        next4 = cidr4.next_subnet(:Bitstep => 2)
        next6 = cidr6.next_subnet(:Bitstep => 2)
        assert_equal('192.168.3.0/24',next4 )
        assert_equal('fec0:0000:0000:0002:0000:0000:0000:0000/64',next6 )

        next4 = cidr4.next_subnet(:Objectify => true)
        next6 = cidr6.next_subnet(:Objectify => true)
        assert_equal('192.168.2.0/24',next4.desc )
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0000/64',next6.desc )
    end

    def test_nth
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/126')

        assert_raise(ArgumentError) {cidr4.nth(1, :test => true)}
        assert_equal('192.168.1.1',cidr4.nth(1) )
        assert_equal('192.168.1.50',cidr4.nth(50) )
        assert_kind_of(NetAddr::CIDR,cidr4.nth(1, :Objectify => true) )
        assert_raise(NetAddr::BoundaryError){ cidr4.nth(256) }
        assert_raise(ArgumentError){ cidr4.nth() }

        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0001',cidr6.nth(1) )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0003',cidr6.nth(3) )
        assert_equal('fec0::1',cidr6.nth(1, :Short => true) )
        assert_raise(NetAddr::BoundaryError){ cidr6.nth(10) }

        assert_raise(ArgumentError) { cidr4.nth({}) }
    end

    def test_range
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64')

        assert_raise(ArgumentError) {cidr4.range(25,0, :test => true)}
        range4 = cidr4.range(25,0, :Bitstep => 5)
        range4_2 = cidr4.range(250)
        range6 = cidr6.range(25,0, :Bitstep => 5, :Short => true)

        assert_equal(6,range4.length)
        assert_equal(6,range4_2.length)
        assert_equal(6,range6.length)
        assert_equal('192.168.1.0',range4[0])
        assert_equal('192.168.1.25',range4[5])
        assert_equal('fec0::',range6[0])
        assert_equal('fec0::19',range6[5])
    end

    def test_remainder
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('192.168.1.64/26')

        assert_raise(ArgumentError) {cidr4.remainder(cidr4_2, :test => true)}
        remainder = cidr4.remainder(cidr4_2)

        assert_equal(2,remainder.length)
        assert_equal('192.168.1.0/26',remainder[0])

        remainder = cidr4.remainder('192.168.1.64/26', :Objectify => true)
        assert_equal('192.168.1.128/25',remainder[1].desc)
    end

    def test_resize
        cidr4 = NetAddr::CIDR.create('192.168.1.129/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_raise(ArgumentError) {cidr4.resize(23, :test => true)}
        new4 = cidr4.resize(23)
        new6 = cidr6.resize(63)
        assert_equal('192.168.0.0/23',new4.desc )
        assert_equal('fec0::/63',new6.desc(:Short => true) )

        cidr4.resize!(25)
        cidr6.resize!(67)
        assert_equal('192.168.1.0/25',cidr4.desc )
        assert_equal('192.168.1.0',cidr4.ip )
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000/67',cidr6.desc )
    end

    def test_set_wildcard_mask
        cidr = NetAddr::CIDR.create('10.1.0.0/24')
        assert_equal('0.0.0.255', cidr.wildcard_mask(true))
        assert_equal('255.255.255.0', cidr.wildcard_mask)

        cidr.set_wildcard_mask('0.7.0.255', true)
        assert_equal('0.7.0.255', cidr.wildcard_mask(true))
        assert_equal('255.248.255.0', cidr.wildcard_mask())
        cidr.set_wildcard_mask('255.248.255.0')
        assert_equal('0.7.0.255', cidr.wildcard_mask(true))
        assert_equal('255.248.255.0', cidr.wildcard_mask())
        cidr.set_wildcard_mask('0.0.0.0')
        assert_equal('0.0.0.0', cidr.wildcard_mask)
        assert_raise(NetAddr::ValidationError){ cidr.set_wildcard_mask('0000:ffff::ffff') }

        cidr = NetAddr::CIDR.create('fec0::1/64')
        assert_equal('0000:0000:0000:0000:ffff:ffff:ffff:ffff', cidr.wildcard_mask(true))
        cidr.set_wildcard_mask('0000:ffff::ffff', true)
        assert_equal('0000:ffff:0000:0000:0000:0000:0000:ffff', cidr.wildcard_mask(true))
        assert_raise(NetAddr::ValidationError){ cidr.set_wildcard_mask('0.7.0.255', true) }
    end

    def test_size
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')
        cidr6 = NetAddr::CIDR.create('fec0::1/64')

        assert_equal(256,cidr4.size() )
        assert_equal(2**64,cidr6.size() )
    end

    def test_subnet
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64') 

        assert_raise(ArgumentError) {cidr4.subnet(:test => true)}
        subnet4 = cidr4.subnet(:Bits => 26, :NumSubnets => 4)
        subnet6 = cidr6.subnet(:Bits => 66, :NumSubnets => 4)
        assert_equal('192.168.1.0/26', subnet4[0])
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000/66', subnet6[0])

        subnet4 = cidr4.subnet(:Bits => 26, :NumSubnets => 1)
        assert_equal('192.168.1.0/26', subnet4[0])
        assert_equal('192.168.1.64/26', subnet4[1])
        assert_equal('192.168.1.128/25', subnet4[2])

        subnet4 = cidr4.subnet(:Bits => 28, :NumSubnets => 3, :Objectify => true)
        assert_equal('192.168.1.0/28', subnet4[0].desc)
        assert_equal('192.168.1.16/28', subnet4[1].desc)
        assert_equal('192.168.1.32/28', subnet4[2].desc)
        assert_equal('192.168.1.48/28', subnet4[3].desc)
        assert_equal('192.168.1.64/26', subnet4[4].desc)
        assert_equal('192.168.1.128/25', subnet4[5].desc)

        subnet4 = cidr4.subnet(:IPCount => 112)
        assert_equal('192.168.1.0/25', subnet4[0])

        subnet4 = cidr4.subnet(:IPCount => 31)
        assert_equal('192.168.1.0/27', subnet4[0])
    end

    def test_succ
        cidr4 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr6 = NetAddr::CIDR.create('fec0::/64')
        cidr4_2 = NetAddr::CIDR.create('255.255.255.0/24')

        assert_equal('192.168.2.0/24',cidr4.succ.desc)
        assert_equal('fec0:0000:0000:0001:0000:0000:0000:0000/64',cidr6.succ.desc )
        assert_raise(NetAddr::BoundaryError) {cidr4_2.succ}
    end

    def test_to_i
        cidr4 = NetAddr::CIDR.create('192.168.1.1/24')

        assert_equal(3232235776,cidr4.to_i )
        assert_equal(4294967040,cidr4.to_i(:netmask) )
        assert_equal(3232235777,cidr4.to_i(:ip) )
        assert_equal(255,cidr4.to_i(:hostmask) )
        assert_equal(4294967040,cidr4.to_i(:wildcard_mask) )
    end

    def test_unique_local
        eui = NetAddr::EUI48.new('abcdef010203')
        cidr = NetAddr::CIDR.create('FC00::/7')
        assert_kind_of(NetAddr::CIDRv6, NetAddr::CIDRv6.unique_local(eui))
        assert(cidr.contains?(NetAddr::CIDRv6.unique_local(eui)) )
    end

    def test_wildcard_mask
        cidr = NetAddr::CIDR.create('10.1.0.0/24', :WildcardMask => ['0.7.0.255', true])
        assert_equal('0.7.0.255', cidr.wildcard_mask(true))
        assert_equal('255.248.255.0', cidr.wildcard_mask)
    end

end




