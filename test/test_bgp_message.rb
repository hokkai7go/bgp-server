require 'minitest/autorun'
require_relative '../bgp-server'

class BGPMessageTest < Minitest::Test
  def setup
    @keepalive_message = BGPMessage.new(BGPMessage::TYPE_KEEPALIVE)
  end

  def test_keepalive_message_binary_representation
    expected_length = 19
    binary_data = @keepalive_message.to_binary
    assert_equal expected_length, binary_data.length

    marker = binary_data[0, 16]
    expected_marker = "\xFF" * 16
    assert_equal expected_marker, marker, 'マーカーが16バイトの0xFFであること'

    message_type = binary_data[18].unpack('C').first
    assert_equal BGPMessage::TYPE_KEEPALIVE, message_type, "タイプがKEEPALIVE (4) であること"
  end

  def test_message_with_payload_length
    payload_data = "Hello BGP" # 9バイトのペイロード

    # UPDATE(2)
    update_message = BGPMessage.new(BGPMessage::TYPE_UPDATE, payload_data)
    expected_length = 19 + payload_data.length

    binary_data = update_message.to_binary
    assert_equal expected_length, binary_data.length

    actual_length_field = binary_data[16, 2].unpack('n').first
    assert_equal expected_length, actual_length_field, 'Lengthフィールドの値が正しいこと'
  end
end
