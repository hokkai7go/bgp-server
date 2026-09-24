require 'minitest/autorun'
require 'ostruct'
require_relative '../lib/bgp_rib'
require_relative '../bgp-server'

class BGPSessionRibCleanupTest < Minitest::Test
  def setup
    @rib = BGPRib.new
    @peer_ip = '192.168.1.1'

    mock_socket = OpenStruct.new(
      peeraddr: ['AF_INET', 179, 'hostname', @peer_ip],
      closed?: false,
      close: nil
    )

    @session = BGPSession.new(mock_socket, 65000, '1.1.1.1', rib: @rib)

    @rib.add_route('10.0.0.0/24', peer_ip: @peer_ip, next_hop: @peer_ip, as_path: [65001])
  end

  def test_terminate_session_removes_peer_routes
    # 初期状態ではRIBに存在する
    assert @rib.get_route('10.0.0.0/24', @peer_ip)

    @session.terminate_session('Hold timer expired')

    assert_nil @rib.get_route('10.0.0.0/24', @peer_ip)
  end
end
