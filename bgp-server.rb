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
  STATE_IDLE = :Idle
  STATE_OPENSENT = :OpenSent
  STATE_OPENCONFIRM = :OpenConfirm
  STATE_ESTABLISHED = :Established

  def initialize(client_socket, my_as, my_router_id)
    @socket = client_socket
    @my_as = my_as
    @my_router_id = my_router_id
    @state     = STATE_OPENSENT
    @hold_time = 180
    @keepalive_interval = 60
    @hold_timer_thread  = nil
    @keepalive_timer_thread = nil
    @parser = BGPMessageParser.new
  end

  def start_keepalive_timer
    @keepalive_timer_thread = Thread.new do
      loop do
        sleep(@keepalive_interval)
        send_keepalive
      end
    end
  end

  def send_keepalive
    keepalive_message = BGPMessage.build_keepalive
    @socket.write(keepalive_message.to_binary)
    puts '--> Sent KEEPALIVE message.'
  rescue => e
    puts "Error sending KEEPALIVE: #{e.message}. Closing session."
    terminate_session
  end

  def start_hold_timer
    @hold_timer_thread.kill if @hold_timer_thread
    @hold_timer_thread = Thread.new do
      puts "Hold Timer started/reset to #{@hold_time}s."
      begin
        Timeout::timeout(@hold_time) do
          Thread.stop
        end
      rescue Timeout::Error
        puts '!!! Hold Timer expired. Terminating session.'
        terminate_session('Hold Timer Expired')
      end
    end
  end

  def reset_hold_timer
    # スレッドが実行中であれば、Timeout::timeout の待機状態を解除する
    # Rubyのスレッド操作は複雑なので、ここでは単純にスレッドを再起動する簡易版を使う
    start_hold_timer
  end

  def transition_to_established
    @state = STATE_ESTABLISHED
    start_keepalive_timer
    start_hold_timer
    puts '*** BGP Session is ESTABLISHED! ***'
  end

  def terminate_session(reason = 'Unknown Error')
    puts "Terminating session. Reason: #{reason}"
    @state = STATE_IDLE
    @socket&.close
    # 自分自身でない場合のみ kill する
    @keepalive_timer_thread&.kill if @keepalive_timer_thread != Thread.current
    @hold_timer_thread&.kill if @hold_timer_thread != Thread.current
  end

  def send_open(hold_time = 180)
    open_message = BGPMessage.build_open(@my_as, hold_time, @my_router_id)
    @socket.write(open_message.to_binary)
    puts '--> Sent OPEN message.'
  end

  def receive_and_handle_open
    # 実際にはデータが完全に揃うまでループする必要があるが、ここでは簡易化
    begin
      data = @socket.readpartial(1024)

      # TODO: BGPMessageParserを使ってデータを BGPMessage オブジェクトに変換する
      # 例: received_msg = @parser.parse(data)

      # ここでは、受信したバイナリデータを直接パースして検証する (テストのため簡易化)
      # 受信データがBGPヘッダー＋最低限のOPENペイロード（19+10=29バイト）以上あるか確認
      if data && data.length >= 29
        marker = data[0, 16]
        type   = data[18].unpack('C').first
        if marker == BGPMessage::MARKER && TYPE == BGPMessage::TYPE_OPEN
          puts '<-- Received valid OPEN message.'
          @state = STATE_OPENCONFIRM
          true
        end
      end
      # 失敗時は NOTIFICATION を送るロジックが本来必要だが、ここでは false を返す
      puts "<-- Received invalid message or not an OPEN message."
      false
    rescue EOFError
      puts "Connection closed by peer."
      false
    rescue => e
      puts "Error during receive: #{e.message}"
      false
    end
  end
end

class BGPRoutingTable
  def initialize
    @entries = {}
  end

  def add_route(prefix, length, attributes)
    key = "#{prefix}/#{length}"
    @entries[key] = { attributes: attributes, timestamp: Time.now }
    puts "Route added: #{key}"
  end

  def withdraw_route(prefix, length)
    key = "#{prefix}/#{length}"
    @entries.delete(key)
    puts "Route withdrawn: #{key}"
  end

  def all_routes
    @entries
  end
end

# PORT = 10179
# @bgp_socket = BGPSocket.new(PORT)
# binding.irb
