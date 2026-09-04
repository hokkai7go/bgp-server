require 'minitest/autorun'
require_relative '../bgp-server'

class BGPUpdateHandlingTest < Minitest::Test
  MY_AS = 65000

  def setup
    # handle_update_message はソケットを使わないため nil で構築できる
    @session = BGPSession.new(nil, MY_AS, '10.0.0.1')
  end

  def build_update_message(as_numbers)
    as_path_value = [2, as_numbers.length].pack('CC') + as_numbers.pack('n*')
    attribute = [0x40, 2, as_path_value.bytesize].pack('CCC') + as_path_value
    payload = [0, attribute.bytesize].pack('nn') + attribute
    BGPMessage.new(BGPMessage::TYPE_UPDATE, payload)
  end

  def test_rejects_route_when_own_as_is_in_path
    msg = build_update_message([65001, MY_AS, 65002])

    refute @session.handle_update_message(msg), '自分のASがAS_PATHに含まれる経路は拒否されること'
  end

  def test_accepts_route_when_no_loop
    msg = build_update_message([65001, 65002])

    assert @session.handle_update_message(msg), 'ループがない経路は受理されること'
  end
end
