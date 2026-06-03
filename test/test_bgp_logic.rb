require 'minitest/autorun'
require_relative '../lib/bgp_message'
require_relative '../lib/bgp_message_parser'

class BGPLogicTest < Minitest::Test
  def test_as_path_flattening
    # AS_SEQUENCE(2), Count(2), AS65001, AS65002
    as_path_value = [2, 2, 65001, 65002].pack('CCnn')
    # Path Attribute: Flags(0x40), Type(2), Length(6)
    attribute = [0x40, 2, as_path_value.bytesize].pack('CCC') + as_path_value
    # UPDATE: Withdrawn(0), TotalAttrLength(9), Attribute
    payload = [0, attribute.bytesize].pack('nn') + attribute

    msg = BGPMessage.new(BGPMessage::TYPE_UPDATE, payload)
    parsed = msg.parse_update_payload

    # 入れ子にならず、フラットな数値配列になっていること
    assert_equal [65001, 65002], parsed[:as_path]
  end

  def test_parser_streaming
    parser = BGPMessageParser.new
    keepalive = BGPMessage.new(BGPMessage::TYPE_KEEPALIVE).to_binary

    parser.append(keepalive[0..10])
    assert_nil parser.next_message

    parser.append(keepalive[11..-1])
    msg = parser.next_message

    assert_equal BGPMessage::TYPE_KEEPALIVE, msg.type
  end
end