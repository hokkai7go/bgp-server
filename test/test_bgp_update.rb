require 'minitest/autorun'
require_relative '../bgp-server'

class BGPUpdateTest < Minitest::Test
  def setup
    @table = BGPRoutingTable.new
  end

  def test_add_route_to_table
    prefix = '10.0.0.0'
    length = 8
    attributes = { next_hop: '192.168.1.1', as_path: [65001] }

    @table.add_route(prefix, length, attributes)

    assert_equal 1, @table.all_routes.size
    assert @table.all_routes.key?('10.0.0.0/8')
  end

  def test_parse_nlri_binary
    # /24 (18進数) + 192.168.10 (C0 A8 0A) のバイナリデータ
    binary_nlri = [24, 192, 168, 10].pack('CCCC')

    routes = BGPMessage.parse_nlri(binary_nlri)

    assert_equal 1, routes.size
    assert_equal '192.168.10.0', routes.first[:prefix]
    assert_equal 24, routes.first[:length]
  end
end
