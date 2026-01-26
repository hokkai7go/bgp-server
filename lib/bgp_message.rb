class BGPMessage
  attr_reader :type, :payload

  TYPE_OPEN         = 1
  TYPE_UPDATE       = 2
  TYPE_NOTIFICATION = 3
  TYPE_KEEPALIVE    = 4

  BGP_VERSION = 4

  # すべてのBGPメッセージは19バイトのヘッダーを持つ
  HEADER_LENGTH = 19
  MARKER        = ("\xFF" * 16).b # 16バイトのマーカー

  attr_reader :type, :payload

  def initialize(type, payload = ''.b)
    @type    = type
    @payload = payload ? payload.b : "".b
  end

  # BGPメッセージ全体をバイナリ形式にパックして返す
  def to_binary
    # 1. メッセージ全体の長さを計算
    length = HEADER_LENGTH + @payload.bytesize

    header = [MARKER, length, @type].pack("a16nC")
    header + @payload
  end

  def self.build_open(my_as, hold_time, router_id, opt_params_payload = '')
    # 1. ペイロード部分を構築
    # 'C':  1バイト (Version)
    # 'n':  2バイト (My AS, Hold Time)
    # 'N':  4バイト (BGP Identifier, ネットワークバイトオーダーの32bit整数)
    # 'C':  1バイト (Optional Parameter Length)
    payload = [
      BGP_VERSION,
      my_as,
      hold_time,
      IPAddr.new(router_id).to_i,
      opt_params_payload.length
    ].pack('Cn n N C') + opt_params_payload
    new(TYPE_OPEN, payload)
  end

  def self.build_keepalive
    new(TYPE_KEEPALIVE, '')
  end

  def self.parse_nlri(binary_data)
    routes = []
    cursor = 0
    while cursor < binary_data.length
      prefix_len = binary_data[cursor].unpack1('C')
      cursor += 1

      byte_len = (prefix_len / 8.0).ceil
      prefix_bytes = binary_data[cursor, byte_len]
      cursor += byte_len

      ip_parts = prefix_bytes.unpack('C*')
      ip_parts << 0 while ip_parts.length < 4
      prefix_addr = ip_parts.join('.')

      routes << { prefix: prefix_addr, length: prefix_len }
    end
    routes
  end
end
