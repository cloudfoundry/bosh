require 'spec_helper'

module Bosh::Director
  RSpec.describe IpAddrOrCidr do
    subject(:ip_addr_or_cidr) { IpAddrOrCidr.new(input) }

    describe '#initialize' do
      context 'when passed an instance of IpAddrOrCidr' do
        let(:input) { IpAddrOrCidr.new('10.10.10.10') }

        it 'succeeds' do
          expect(IpAddrOrCidr.new(input)).to eq(input)
        end
      end

      context 'when passed an instance of integer' do
        context 'less than or equal to 0xffffffff (IPv4 max int)' do
          let(:input) { IPAddr::IN4MASK }

          it 'creates an IPv4 address' do
            expect(IpAddrOrCidr.new(input)).to be_ipv4
          end
        end

        context 'greater than 0xffffffff (IPAddr::IN4MASK)' do
          let(:input) { IPAddr::IN4MASK + 1 }

          it 'creates an IPv6 address' do
            expect(IpAddrOrCidr.new(input)).to be_ipv6
          end
        end

        context 'greater than 0xffffffffffffffffffffffffffffffff (IPv6 max int)' do
          let(:input) { IPAddr::IN6MASK + 1 }

          it 'raises an exception' do
            expect { IpAddrOrCidr.new(input) }.to raise_error(IPAddr::InvalidAddressError)
          end
        end
      end
    end

    describe '#count' do
      context 'when initialized with a single IP' do
        context 'IPv4' do
          let(:input) { '192.168.0.1' }

          it 'returns 1' do
            expect(ip_addr_or_cidr.count).to eq(1)
          end
        end

        context 'IPv6' do
          let(:input) { '2001:0db8:85a3:0000:0000:8a2e:0370:7334' }

          it 'returns 1' do
            expect(ip_addr_or_cidr.count).to eq(1)
          end
        end
      end
    end

    describe '#to_cidr_s' do
      context 'IPv4' do
        let(:input) { '192.168.0.0/24' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_cidr_s).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { 'fd00::/8' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_cidr_s).to eq(input)
        end
      end
    end

    describe '#to_i' do
      context 'IPv4' do
        let(:input) { '10.20.0.32' }

        it 'returns an integer representing the IP' do
          expect(ip_addr_or_cidr.to_i).to eq(169082912)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:0db8:85a3:7334:8a2e:0000:0000:0000' }

        it 'returns an integer representing the IP' do
          expect(ip_addr_or_cidr.to_i).to eq(42540766452641698113073181315785818112)
        end
      end
    end

    describe '#to_s' do
      context 'IPv4' do
        let(:input) { '10.20.0.32' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:db8:85a3:7334:8a2e::' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_s).to eq(input)
        end
      end
    end

    describe '#to_string' do
      context 'IPv4' do
        let(:input) { '10.20.0.32' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_string).to eq(input)
        end
      end

      context 'IPv6' do
        let(:input) { '2001:0db8:85a3:7334:8a2e:0000:0000:0000' }

        it 'returns a string representing the IP' do
          expect(ip_addr_or_cidr.to_string).to eq(input)
        end
      end
    end
  end
end
