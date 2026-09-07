require 'minitest/autorun'
require_relative '../lib/bgp_message'

class BGPUpdateParsingTest < Minitest::Test
  def test_parse_as_path_sequence
    # AS_PATH binary
    # Segment: AS_SEQUENCE(2), Count(2), AS65001(FDE9), AS65002(FDEA)
    as_path_value = [2, 2, 65001, 65002].pack('CCnn')

    # Path Attribute: Flags(0x40), Type(2), Length(6), Value(...)
    attribute = [0x40, 2, as_path_value.bytesize].pack('CCC') + as_path_value

    payload = [0, attribute.bytesize].pack('nn') + attribute

    message = BGPMessage.new(BGPMessage::TYPE_UPDATE, payload)
    parsed = message.parse_update_payload

    assert_equal 0, parsed[:withdrawn].length
    assert_kind_of Array, parsed[:as_path]
    assert_equal [65001, 65002], parsed[:as_path], "セグメントタイプとAS_PATHが正しく数値の配列として抽出されること"
  end
end
