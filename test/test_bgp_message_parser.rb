require 'minitest/autorun'
require 'ipaddr'
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

    @parser.append(@keepalive[11..-1])
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

  def test_parse_update_message_with_as_path
    # BGP UPDATE メッセージのペイロードを作成
    # 1. Withdrawn Routes Length (2 bytes, 0)
    withdrawn_routes_length = [0].pack('n')
    withdrawn_routes = ''.b

    # 2. Path Attributes
    #   - ORIGIN (Type 1), 1 byte, value 0 (IGP)
    origin_attribute = [0x40, 1, 1, 0].pack('CCCC')
    #   - AS_PATH (Type 2), AS_SEQUENCE with AS 65001
    as_path_segment = [2, 1, 65001].pack('CCn') # Segment Type 2, 1 AS, AS 65001
    as_path_attribute = [0x40, 2, as_path_segment.length].pack('CCC') + as_path_segment
    #   - NEXT_HOP (Type 3), 192.0.2.1
    next_hop_attribute = [0x40, 3, 4, IPAddr.new('192.0.2.1').to_i].pack('CCCN')

    path_attributes = origin_attribute + as_path_attribute + next_hop_attribute
    total_path_attributes_length = [path_attributes.length].pack('n')

    # 3. NLRI (Network Layer Reachability Information)
    # 192.0.2.0/24
    nlri = [24, 192, 0, 2].pack('CCCC')

    # UPDATE ペイロード全体
    payload = withdrawn_routes_length + withdrawn_routes +
              total_path_attributes_length + path_attributes +
              nlri

    # BGP メッセージ全体
    update_message = BGPMessage.new(BGPMessage::TYPE_UPDATE, payload).to_binary
    @parser.append(update_message)
    message = @parser.next_message

    assert_instance_of BGPMessage, message
    assert_equal BGPMessage::TYPE_UPDATE, message.type

    update_info = message.parse_update_payload
    # AS_PATH の検証
    assert_equal [[2, [65001]]], update_info[:as_path]
    # NLRI の検証
    assert_equal [{ prefix: '192.0.2.0', length: 24 }], update_info[:nlri]
  end
end
