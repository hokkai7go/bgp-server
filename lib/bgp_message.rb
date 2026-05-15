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

  def parse_update_payload
    attrs = parse_attributes(attr_data)
  end

  private

  def parse_attributes(data)
    attrs = { as_path: [] }
    cursor = 0
    while cursor < data.bytesize
      flags = data.getbyte(cursor)
      type  = data.getbyte(cursor + 1)

      # 属性の長さを取得 (Extended Length対応 RFC8654?)
      len_size = (flags & 0x10 != 0) ? 2 : 1
      len = (len_size == 2) ? data.byteslice(cursor + 2, 2).unpack1("n") : data.getbyte(cursor + 2)

      header_size = 2 + len_size
      value = data.byteslice(cursor + header_size, len)

      case type
      when 2 # AS_PATH
        attrs[:as_path] = parse_as_path(value)
      when 3 # NEXT_HOP
        attrs[:next_hop] = value.unpack("C*").join('.')
      end
      cursor += (header_size + len)
    end
    attrs
  end

  def parse_as_path(data)
    path = []
    cursor = 0
    while cursor < data.bytesize
      # seg_type (1: AS_SET, 2: AS_SEQUENCE)
      # seg_len: (AS番号の個数)
      _seg_type = data.getbyte(cursor)
      seg_len   = data.getbyte(cursor + 1)
      cursor += 2

      seg_len.times do
        # 2バイトずつAS番号を取り出して、フラットな配列に放り込む
        path << data.byteslice(cursor, 2).unpack1("n")
        cursor += 2
      end
    end
    path
  end
end
