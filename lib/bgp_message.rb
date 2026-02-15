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

  def parse_update_payload
    info = { withdrawn_routes: [], path_attributes: {}, nlri: [] }
    cursor = 0

    # 1. Withdrawn Routes
    withdrawn_len = @payload[cursor, 2].unpack1('n')
    cursor += 2
    # Withdrawn routes parsing would go here, but we skip for now.
    cursor += withdrawn_len

    # 2. Path Attributes
    path_attr_len = @payload[cursor, 2].unpack1('n')
    cursor += 2
    path_attr_end = cursor + path_attr_len
    info.merge!(self.class.parse_path_attributes(@payload.byteslice(cursor, path_attr_len)))
    cursor = path_attr_end

    # 3. NLRI
    nlri_data = @payload.byteslice(cursor..-1)
    info[:nlri] = self.class.parse_nlri(nlri_data) if nlri_data && !nlri_data.empty?

    info
  end

  def self.parse_path_attributes(binary_data)
    attributes = {}
    cursor = 0
    while cursor < binary_data.length
      _flags, type_code, length = binary_data[cursor, 3].unpack('CCC')
      cursor += 3 # 1 byte for length
      value = binary_data.byteslice(cursor, length)
      cursor += length

      case type_code
      when 2 # AS_PATH
        attributes[:as_path] = parse_as_path(value)
      end
    end
    attributes
  end

  def self.parse_as_path(binary_data)
    as_path = []
    cursor = 0
    while cursor < binary_data.length
      segment_type, segment_length = binary_data[cursor, 2].unpack('CC')
      cursor += 2
      segment_end = cursor + (segment_length * 2) # AS numbers are 2 bytes
      segment_asns = binary_data.byteslice(cursor, segment_length * 2).unpack('n*')
      as_path << [segment_type, segment_asns]
      cursor = segment_end
    end
    as_path
  end
end
