class BGPMessageParser
  def initialize
    @buffer = ''.b
  end

  def append(data)
    @buffer << data.b if data
  end

  def next_message
    return nil if @buffer.bytesize < 19
    # 1. 最初の16バイト（マーカー）を確認し、中身を見ずに一旦飛ばす
    # 2. 次の2バイトを「長さ」として取得
    # byteslice(16, 2) で 17, 18 バイト目を確実に狙う
    length_bytes = @buffer.byteslice(16, 2)
    length = length_bytes.unpack1("n")

    p "Debug: raw_length_bytes=#{length_bytes.unpack1('H*')}, length=#{length}"

    return nil if @buffer.bytesize < length
    message_data = @buffer.byteslice(0, length)
    @buffer = @buffer.byteslice(length..-1) || ''.b
    parse_binary(message_data)
  end

  private

  def parse_binary(data)
    type = data.getbyte(18)
    payload = data.byteslice(19..-1) || ''.b
    BGPMessage.new(type, payload)
  end
end
