require 'minitest/autorun'
require_relative '../lib/bgp_rib'

class BGPBestPathTest < Minitest::Test
  def setup
    @rib = BGPRib.new
  end

  def test_select_shortest_as_path
    prefix = '10.0.0.0/24'

    # 3つAS経由するルート
    @rib.add_route(prefix, peer_ip: '192.168.1.1', next_hop: '192.168.1.1', as_path: [65001, 65002, 65003])

    # 1AS経由するルート
    @rib.add_route(prefix, peer_ip: '192.168.2.2', next_hop: '192.168.2.2', as_path: [65010])

    best_route = @rib.select_best_path(prefix)
    binding.irb

    # AS_PATHが短いルート2 (peer_ip: 192.168.2.2)が選ばれること
    assert_equal '192.168.2.2', best_route[:peer_ip], 'AS_PATHが短いルートが選ばれること'
    assert_equal [65010], best_route[:as_path]
  end
end
