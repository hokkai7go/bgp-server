require 'minitest/autorun'
require_relative '../lib/bgp_rib'

class BGPRibTest < Minitest::Test
  def setup
    @rib = BGPRib.new
  end

  def test_add_and_get_route
    peer_ip  = '192.168.1.1'
    prefix   = '10.0.0.0/24'
    next_hop = '192.168.1.1'
    as_path  = [65001, 65002]

    @rib.add_route(prefix, peer_ip: peer_ip, next_hop: next_hop, as_path: as_path)

    route = @rib.get_route(prefix, peer_ip)
    assert route, '追加した経路がRIBに存在すること'
    assert_equal next_hop, route[:next_hop]
    assert_equal as_path, route[:as_path]
  end
end
