require 'minitest/autorun'
require 'socket'
require 'thread'
require_relative '../bgp-server'

class BGPSocketTest < Minitest::Test
  TEST_PORT = 10179

  def setup
    @bgp_socket = BGPSocket.new(TEST_PORT)
    @queue = Queue.new
  end

  def teardown
    @bgp_socket.stop_listening
  end

  def test_start_listening_success
    server_socket = @bgp_socket.start_listening
    assert server_socket, 'start_listeningはソケットオブジェクトを返すこと'

    begin
      client = TCPSocket.new('127.0.0.1', TEST_PORT)
      assert client, 'クライアントがBGPサーバーに接続できること'
    ensure
      client&.close
    end
  end

  def test_accept_connection_success
    server_thread = Thread.new do
      begin
        @bgp_socket.start_listening

        client_conn = @bgp_socket.accept_connection

        # 接続が成功したら、スレッド間の通信のためにキューに信号を送る
        @queue.push(:connected)

        client_conn.close
      rescue => e
        @queue.push(e)
      end
    end

    # 2. サーバーソケットが立ち上がるのを少し待つ (必須ではないが安全のため)
    sleep(0.1)

    client_socket = TCPSocket.new('127.0.0.1', TEST_PORT)
    client_socket.close

    result = Timeout::timeout(2) { @queue.pop }

    assert_equal :connected, result, 'サーバー側でクライアント接続が正しく受け入れられたこと'

    server_thread.join

    rescue Timeout::Error
      flunk '接続タイムアウト: サーバーが時間内に接続を受け入れられませんでした。'
    rescue Exception => e
      flunk "予期せぬエラー: #{e.message}"
    end
end
