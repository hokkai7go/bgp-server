require 'minitest/autorun'
require_relative '../lib/bgp_message'
require_relative '../lib/bgp_message_parser'

class BGPMessageParserTest < Minitest::Test
  def setup
    @parser = BGPMessageParser.new
    @keepalive = BGPMessage.new(BGPMessage::TYPE_KEEPALIVE).to_binary
  end

  def test_partial_data_receive
    @parser.append(@keepalive[0..10])
    assert_nil @parser.next_message, 'データが足りないときはnilを返すこと'

    @parser.append(@keepalive[10..-1])
    message = @parser.next_message
    assert_instance_of BGPMessage, message
    assert_equal BGPMessage::TYPE_KEEPALIVE, message.type
  end

  def test_multiple_messages_at_once
    @parser.append(@keepalive + @keepalive)

    message1 = @parser.next_message
    assert_equal BGPMessage::TYPE_KEEPALIVE, message1.type

    message2 = @parser.next_message
    assert_equal BGPMessage::TYPE_KEEPALIVE, message2.type

    assert_nil @parser.next_message
  end
end
