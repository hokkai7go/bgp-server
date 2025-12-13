require 'socket'
require 'ipaddr'

class BGPMessage
  TYPE_OPEN         = 1
  TYPE_UPDATE       = 2
  TYPE_NOTIFICATION = 3
  TYPE_KEEPALIVE    = 4

  BGP_VERSION = 4

  # すべてのBGPメッセージは19バイトのヘッダーを持つ
  HEADER_LENGTH = 19
  MARKER        = "\xFF" * 16 # 16バイトのマーカー

  attr_reader :type, :payload

  def initialize(type, payload = '')
    @type    = type
    @payload = payload
  end

  # BGPメッセージ全体をバイナリ形式にパックして返す
  def to_binary
    # 1. メッセージ全体の長さを計算
    length = HEADER_LENGTH + @payload.length

    # 2. バイナリ形式にパック
    #   'a16': 16バイト文字列 (Marker)
    #   'n':   2バイト符号なし整数 (Length, ネットワークバイトオーダー)
    #   'C':   1バイト符号なし整数 (Type)
    #   'a*':  残りのペイロード
    [
      MARKER,
      length,
      @type,
      @payload
    ].pack('a16nCa*')
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
end

class BGPMessageParser
end

class BGPSocket
  attr_reader :port

  def initialize(port)
    @port = port
    @server_socket = nil
  end

  def start_listening
    begin
      @server_socket = TCPServer.open(@port)
      puts "BGP Server listening on port #{@port}..."
      @server_socket
    rescue => e
      puts "Error starting listener: #{e.message}"
      nil
    end
  end

  def accept_connection
    raise 'Server is not listening. Call start_listening first.' unless @server_socket
    client_socket = @server_socket.accept
    puts "Connection established from #{client_socket.peeraddr.last}"
    client_socket
  end

  def stop_listening
    @server_socket&.close
    @server_socket = nil
    puts 'BGP Server stopped listening.'
  end
end

class BGPSession
  def initialize(client_socket, my_as, my_router_id)
    @socket = client_socket
    @my_as = my_as
    @my_router_id = my_router_id
    @state = :OpenSent
    @parser = BGPMessageParser.new
  end

  def send_open(hold_time = 180)
    open_message = BGPMessage.build_open(@my_as, hold_time, @my_router_id)
    @socket.write(open_message.to_binary)
    puts '--> Sent OPEN message.'
  end

  def receive_and_handle_open
    # 実際にはデータが完全に揃うまでループする必要があるが、ここでは簡易化
    data = @socket.read(1024)

    # TODO: BGPMessageParserを使ってデータを BGPMessage オブジェクトに変換する
    # 例: received_msg = @parser.parse(data)

    # ここでは、受信したバイナリデータを直接パースして検証する (テストのため簡易化)
    # 受信データがBGPヘッダー＋最低限のOPENペイロード（19+10=29バイト）以上あるか確認
    if data && data.length >= 29
      marker = data[0, 16]
      type   = data[18].unpack('C').first
      if marker == BGPMessage::MARKER && TYPE == BGPMessage::TYPE_OPEN
        puts '<-- Received valid OPEN message.'
        @state = :OpenConfirm
        true
      end
    end
    # 失敗時は NOTIFICATION を送るロジックが本来必要だが、ここでは false を返す
    puts "<-- Received invalid message or not an OPEN message."
    false
  end
end

class BGPRoutingTable
end

# PORT = 10179
# @bgp_socket = BGPSocket.new(PORT)
# binding.irb
