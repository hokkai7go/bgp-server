require 'minitest/autorun'
require_relative '../lib/bgp_message'

class BGPNotificationTest < Minitest::Test
  def test_build_and_parse_notification_round_trip
    message = BGPMessage.build_notification(
      BGPMessage::NOTIFICATION_ERROR_CODE_MESSAGE_HEADER,
      3,
      'extra debug data'
    )

    assert_equal BGPMessage::TYPE_NOTIFICATION, message.type

    # 送信直前と同じバイト列を受信側と同じ経路(parse_binary相当)で復元できること
    parsed_message = BGPMessage.new(message.type, message.payload)
    parsed = parsed_message.parse_notification_payload

    assert_equal BGPMessage::NOTIFICATION_ERROR_CODE_MESSAGE_HEADER, parsed[:error_code]
    assert_equal 3, parsed[:error_subcode]
    assert_equal 'extra debug data', parsed[:data]
  end

  def test_parse_notification_payload_returns_nil_for_other_types
    keepalive = BGPMessage.build_keepalive
    assert_nil keepalive.parse_notification_payload
  end
end
