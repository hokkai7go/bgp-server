class BGPRib
  def initialize
    @table = Hash.new { |hash, key| hash[key] = {} }
  end

  def add_route(prefix, peer_ip:, next_hop:, as_path:)
    @table[prefix][peer_ip] = {
      next_hop:    next_hop,
      as_path:     as_path,
      received_at: Time.now
    }
  end

  def select_best_path(prefix)
    peers = @table[prefix]
    return nil if peers.empty?

    # ベストパスを選ぶ
    best_peer_ip, best_route_data = peers.min_by do |peer_ip, route|
      route[:as_path].length
    end
    best_route_data.merge(peer_ip: best_peer_ip)
  end

  def get_route(prefix, peer_ip)
    @table[prefix][peer_ip]
  end

  # 特定のピアから受け取ったすべての経路を削除（セッション切断時用）
  def remove_route_from_peer(peer_ip)
    @table.each do |prefix, peers|
      peers.delete(peer_ip)
    end

  @table.reject! { |_, peers| peers.empty? }
  end
end
