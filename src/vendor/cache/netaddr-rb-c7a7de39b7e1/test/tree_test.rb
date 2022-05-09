#!/usr/bin/ruby

require_relative "../lib/netaddr.rb"
require 'test/unit'



class TestTree < Test::Unit::TestCase

    def test_add
        tree = NetAddr::Tree.new()

        assert_nothing_raised(RuntimeError){tree.add!('192.168.1.0 255.255.255.0')}
        assert_nothing_raised(RuntimeError){tree.add!('10.1.0.0/24')}
        assert_nothing_raised(RuntimeError){tree.add!('10.1.0.0')}
        assert_nothing_raised(RuntimeError){tree.add!('192.168.1.0/26')}
        assert_nothing_raised(RuntimeError){tree.add!('fec0::/10')}
        assert_nothing_raised(RuntimeError){tree.add!('fec0::/64')}

    end

    def test_ancestors
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.64/27')
        tree.add!('192.168.1.64/28')
        tree.add!('192.168.2.0/24')

        ancestors = tree.ancestors('192.168.1.64/28')
        assert_equal('192.168.1.64/27', ancestors[0].desc)
        assert_equal('192.168.1.64/26', ancestors[1].desc)
        assert_equal('192.168.1.0/24', ancestors[2].desc)

    end

    def test_children
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.64/27')
        tree.add!('192.168.1.96/27')
        tree.add!('192.168.1.64/28')
        tree.add!('192.168.2.0/24')

        children = tree.children('192.168.1.64/26')
        assert_equal('192.168.1.64/27', children[0].desc)
        assert_equal('192.168.1.96/27', children[1].desc)
    end

    def test_delete
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.64/27')
        tree.add!('192.168.1.64/28')
        tree.add!('192.168.2.0/24')

        tree.delete!('192.168.1.64/27')
        assert_equal('192.168.1.64/28', tree.children('192.168.1.64/26')[0].desc)
    end

    def test_descendants
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.64/27')
        tree.add!('192.168.1.96/27')
        tree.add!('192.168.1.64/28')
        tree.add!('192.168.2.0/24')

        descendants = tree.descendants('192.168.1.64/26')
        assert_equal('192.168.1.64/27', descendants[0].desc)
        assert_equal('192.168.1.64/28', descendants[1].desc)
        assert_equal('192.168.1.96/27', descendants[2].desc)
    end

    def test_dump
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('10.1.0.0/24')
        tree.add!('192.168.1.0/26')
        tree.add!('192.168.1.0/30')
        tree.add!('fec0::/10')
        tree.add!('fe80::/10')
        tree.add!('fec0::/64')
        tree.add!('fec0::/126')

        dump = tree.dump()

        obj0 = dump[0][:CIDR]
        obj1 = dump[1][:CIDR]
        obj3 = dump[3][:CIDR]
        assert_equal('10.1.0.0/24', obj0.desc)
        assert_equal('192.168.1.0/24', obj1.desc)
        assert_equal('192.168.1.0/30', obj3.desc)

        obj4 = dump[4][:CIDR]
        obj5 = dump[5][:CIDR]
        obj7 = dump[7][:CIDR]
        assert_equal('fe80:0000:0000:0000:0000:0000:0000:0000/10', obj4.desc)
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000/10', obj5.desc)
        assert_equal('fec0:0000:0000:0000:0000:0000:0000:0000/126', obj7.desc)

    end

    def test_exists

        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('10.1.0.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('10.1.0.44/30')

        assert_equal(true, tree.exists?('192.168.1.0/24'))
        assert_equal(true, tree.exists?('10.1.0.44/30'))
        assert_equal(false, tree.exists?('10.2.0.0/24'))

    end

    def test_fill_in
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')

        tree.fill_in!('192.168.1.0/24')
        children = tree.children('192.168.1.0/24')

        assert_equal('192.168.1.0/26', children[0].desc)
        assert_equal('192.168.1.64/26', children[1].desc)
        assert_equal('192.168.1.128/25', children[2].desc)
    end

    def test_find
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('10.1.0.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('10.1.0.44/30')
        assert_equal('192.168.1.64/26', tree.longest_match('192.168.1.64/26').desc)
        assert_equal('10.1.0.44/30', tree.longest_match('10.1.0.44/30').desc)
    end

     def test_find_space
        tree = NetAddr::Tree.new()

        cidr = ['192.168.1.0/24','192.168.1.0/26','192.168.1.64/26',
          '192.168.1.128/26','192.168.1.192/26','192.168.1.0/27',
          '192.168.1.0/28','192.168.1.16/30','192.168.1.16/29',
          '192.168.1.32/27','192.168.1.24/30','192.168.1.28/30',
          '192.168.1.64/27','192.168.1.25',
          'fec0::/60','fec0::/66','fec0::4000:0:0:0/66',
          'fec0::8000:0:0:0/66','fec0::c000:0:0:0/66','fec0::c000:0:0:0/67',
          'fec0::/67','fec0::2000:0:0:0/67','fec0::8000:0:0:0/67','fec0::4000:0:0:0/69']

        assert_raise(ArgumentError) {tree.find_space(:test => true)}
        cidr.each {|x| tree.add!(x)}
        assert_equal(10, tree.find_space(:IPCount => 16).length)
    end

    def test_longest_match

        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('10.1.0.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('10.1.0.44/30')

        assert_equal('192.168.1.64/26', tree.longest_match('192.168.1.65').desc)
        assert_equal('10.1.0.44/30', tree.longest_match('10.1.0.46').desc)
        assert_equal('0.0.0.0/0', tree.longest_match('192.168.2.0').desc )     

    end

    def test_merge_subnets
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.0/26')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.192/26')

        tree.merge_subnets!('192.168.1.0/24')
        children = tree.children('192.168.1.0/24')

        assert_equal('192.168.1.0/25', children[0].desc)
        assert_equal('192.168.1.192/26', children[1].desc)
    end

    def test_prune
        cidr4_1 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('10.1.0.0/24')
        cidr4_3 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr4_4 = NetAddr::CIDR.create('192.168.1.0/30')
        cidr4_5 = NetAddr::CIDR.create('192.168.1.64/26')
        cidr4_6 = NetAddr::CIDR.create('192.168.1.128/26')
        cidr4_7 = NetAddr::CIDR.create('192.168.1.192/26')

        tree4 = NetAddr::Tree.new()

        tree4.add!(cidr4_1)
        tree4.add!(cidr4_2)
        tree4.add!(cidr4_3)
        tree4.add!(cidr4_4)
        tree4.add!(cidr4_5)
        tree4.add!(cidr4_6)
        tree4.add!(cidr4_7)

        tree4.prune!(cidr4_5)
        dump = tree4.dump
        assert_equal(7, dump.length)

        tree4.prune!(cidr4_1)
        dump = tree4.dump        
        assert_equal(2, dump.length)
    end

    def test_remove
        cidr4_1 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('10.1.0.0/24')
        cidr4_3 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr4_4 = NetAddr::CIDR.create('192.168.1.0/30')
        cidr4_5 = NetAddr::CIDR.create('192.168.1.64/26')
        cidr4_6 = NetAddr::CIDR.create('192.168.1.128/26')
        cidr4_7 = NetAddr::CIDR.create('192.168.1.192/26')

        tree4 = NetAddr::Tree.new()

        tree4.add!(cidr4_1)
        tree4.add!(cidr4_2)
        tree4.add!(cidr4_3)
        tree4.add!(cidr4_4)
        tree4.add!(cidr4_5)
        tree4.add!(cidr4_6)
        tree4.add!(cidr4_7)

        tree4.remove!(cidr4_5)
        dump = tree4.dump
        assert_equal(6, dump.length)

        tree4.remove!(cidr4_1)
        dump = tree4.dump
        assert_equal(1, dump.length)
    end

    def test_root
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.64/27')
        tree.add!('192.168.2.0/24')

        assert_equal('192.168.1.0/24', tree.root('192.168.1.64/27').desc)
    end

    def test_show
        cidr4_1 = NetAddr::CIDR.create('192.168.1.0/24')
        cidr4_2 = NetAddr::CIDR.create('10.1.0.0/24')
        cidr4_3 = NetAddr::CIDR.create('192.168.1.0/26')
        cidr4_4 =NetAddr::CIDR.create('192.168.1.0/30')
        cidr4_5 = NetAddr::CIDR.create('192.168.1.64/26')
        cidr4_6 = NetAddr::CIDR.create('192.168.1.128/26')
        cidr4_7 = NetAddr::CIDR.create('192.168.1.192/26')

        tree4 = NetAddr::Tree.new()

        tree4.add!(cidr4_1)
        tree4.add!(cidr4_2)
        tree4.add!(cidr4_3)
        tree4.add!(cidr4_4)
        tree4.add!(cidr4_5)
        tree4.add!(cidr4_6)
        tree4.add!(cidr4_7)

        assert_not_nil(tree4.show())
    end

    def test_siblings
        tree = NetAddr::Tree.new()

        tree.add!('192.168.1.0/24')
        tree.add!('192.168.1.0/26')
        tree.add!('192.168.1.64/26')
        tree.add!('192.168.1.128/26')
        tree.add!('192.168.1.192/26')

        assert_equal(3, tree.siblings('192.168.1.0/26').length)
    end

    def test_interactions
        show1 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.8/29\n      192.168.12.8/30\n"
        show2 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.8/29\n      192.168.12.8/30\n      192.168.12.12/30\n"
        show3 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.0/29\n   192.168.12.8/29\n      192.168.12.8/30\n" +
                "      192.168.12.12/30\n   192.168.12.16/28\n   192.168.12.32/27\n"
        show4 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.0/29\n   192.168.12.8/30\n   192.168.12.12/30\n" +
                "   192.168.12.16/28\n   192.168.12.32/27\n"
        show5 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.0/28\n      192.168.12.0/29\n" +
                "      192.168.12.8/29\n         192.168.12.8/30\n         192.168.12.12/30\n   192.168.12.16/28\n   192.168.12.32/27\n"
        show6 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.0/28\n      192.168.12.0/29\n" +
                "      192.168.12.8/29\n   192.168.12.16/28\n   192.168.12.32/27\n"
        show7 = "IPv4 Tree\n---------\n192.168.12.0/26\n   192.168.12.16/28\n   192.168.12.32/27\n"
        show8 = "IPv4 Tree\n---------\n192.168.12.0/24\n   192.168.12.16/28\n   192.168.12.32/27\n   192.168.12.64/26\n"
        show9 = "IPv4 Tree\n---------\n192.168.12.0/24\n   192.168.12.0/25\n      192.168.12.0/26\n" +
                "         192.168.12.16/28\n         192.168.12.32/27\n      192.168.12.64/26\n"

        tree = NetAddr::Tree.new
        tree.add!('192.168.12.0/26')
        tree.add!('192.168.12.8/29')
        tree.add!('192.168.12.8/30')
        assert_equal(show1, tree.show)
        tree.fill_in! '192.168.12.8/29'
        assert_equal(show2, tree.show)
        tree.fill_in! '192.168.12.0/26'
        assert_equal(show3, tree.show)
        tree.delete!('192.168.12.8/29')
        assert_equal(show4, tree.show)
        tree.add!('192.168.12.8/29')
        tree.add!('192.168.12.0/28')
        tree.add!('192.168.12.0/29')
        assert_equal(show5, tree.show)
        tree.prune!('192.168.12.8/29')
        assert_equal(show6, tree.show)
        tree.remove!('192.168.12.0/28')
        assert_equal(show7, tree.show)
        tree.add!('192.168.12.64/26')
        tree.resize!('192.168.12.0/26', 24)
        assert_equal(show8, tree.show)
        tree.add!('192.168.12.0/26')
        tree.summarize_subnets!('192.168.12.0/24')
        assert_equal(show9, tree.show)
    end

end




