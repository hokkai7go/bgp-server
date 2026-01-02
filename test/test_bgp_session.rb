require 'minitest/autorun'
require 'socket'
require 'thread'
require 'timeout'
require_relative '../bgp-server'

class BGPSessionTest < Minitest::Test
  TEST_PORT = 10180
  SERVER_AS = 65001
  SERVER_RID = '192.0.2.1'
  CLIENT_AS = 65002
  CLIENT_RID = '192.0.2.2'

  def build_client_open_message
    BGPMessage.build_open(CLIENT_AS, 180, CLIENT_RID).to_binary
  end

  def test_open_message_exchange_success
    server_socket = TCPServer.new(TEST_PORT)
    server_thread = nil

    begin
      # server logic
      server_thread = Thread.new do
        Thread.current.abort_on_exception = true # エラー時にすぐ止める
        client_conn = server_socket.accept
        session = BGPSession.new(client_conn, SERVER_AS, SERVER_RID)

        session.send_open
        received_ok = session.receive_and_handle_open
        Thread.current[:result] = received_ok
        client_conn&.close
      end

      # client logic
      sleep(0.1)
      client_socket = TCPSocket.new('127.0.0.1', TEST_PORT)
      server_open_data = Timeout::timeout(2) { client_socket.readpartial(1024) }
      client_socket.write(build_client_open_message)

      assert server_open_data && server_open_data.length >= 29, 'サーバーからデータを受信できたこと'

      server_thread.join
      server_result = server_thread[:result]

      assert_equal true, server_result, 'サーバーがクライアントのOPENメッセージを正しく受信・検証できたこと'

    rescue Timeout::Error
      flunk "メッセージ交換がタイムアウトしました。"
    ensure
      server_socket&.close
      server_thread.join if server_thread && server_thread.alive?
    end
  end
end
