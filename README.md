# bgp-server

To understand BGP4, read the RFC and implement it. Guided by Gemini. This is personal project.

## BGPサーバーとして必要だと考える要件

Linuxマシンを実際にBGPルータとして動かすことを目標に、RFC 4271 (BGP-4) を中心に必要と考えた要件と、その理由をまとめる。カッコ内は本セッション（Claude Codeによる実装調査）時点での実装状況。

### コアプロトコル要件（RFC 4271 必須）

- **セッション確立の状態機械 (Idle/Connect/Active/OpenSent/OpenConfirm/Established)**: BGPはTCP上のステートフルなプロトコルであり、状態遷移を正しく実装しないとピアと接続を確立・維持できない（一部実装済み。現状は状態が単純化されておりConnect/Activeが存在しない）。
- **OPEN/UPDATE/KEEPALIVE/NOTIFICATIONの4メッセージ種別**: この4種別だけでBGPは成立しており、いずれか一つでも欠けると仕様に準拠したピアとして振る舞えない（OPEN/UPDATE/KEEPALIVEは実装済み。NOTIFICATIONは今回未実装だったため今回追加した）。
- **Hold Timer / Keepalive Timerによるセッション死活監視**: TCP接続が生きていてもBGPピアがフリーズしている場合を検知し、古い経路情報を掴み続けないようにするための仕組み（実装済み）。
- **UPDATEメッセージの解析（Withdrawn Routes / NLRI / パス属性: AS_PATH, NEXT_HOP, ORIGIN, LOCAL_PREF, MED等）**: 経路情報の交換こそがBGPの本質的な価値であり、属性を正しく解釈できなければ経路選択もループ防止もできない（NLRI/AS_PATH/NEXT_HOPの基本部分のみ実装済み。ORIGIN/LOCAL_PREF/MEDは未実装）。
- **AS_PATHによるループ防止**: 自AS番号がAS_PATHに含まれる経路を受理すると経路ループが発生しうるため、RFC上必須のセーフガード（実装済み。ただし今回の調査で「ループを検出しても常に経路を受理してしまう」バグが見つかったため修正した）。
- **不正メッセージに対するNOTIFICATION送信とセッションクローズ**: プロトコル違反を検知した際に無言で切断せずエラーコードを通知することは、対向機器の運用者が原因を特定するために必要（今回未実装だったため最小限のMessage Header Errorケースを追加した）。
- **RIB (Routing Information Base) とベストパス選択**: 複数ピアから同一プレフィックスの経路を受け取った際にどれを使うか決めるロジックがなければ経路が不定になる（AS_PATH長による簡易選択のみ実装済み。LOCAL_PREF等RFC 4271 9.1.2.2のフルの選択基準は未実装）。
- **複数ピアの同時収容**: ルータとして意味を持たせるには最低でも複数の隣接ASと同時にセッションを維持できる必要がある（セッション単位のクラスは実装済みだが、複数セッションを束ねて管理する層は未実装）。

### 「Linuxをルータ化する」ために必要な要件

- **学習した経路のカーネルルーティングテーブルへの反映**: BGPで経路情報を交換できても、それをLinuxカーネル（`ip route` / netlink経由）に反映しなければ実際のパケット転送には一切影響しない。本プロジェクトの目的である「LinuxマシンをBGP扱えるルータにする」ことの本丸だが、現状RIBはメモリ上に保持するのみでカーネルへの注入は未実装（spec.md上も明示的にスコープ外とされている）。
- **設定管理（AS番号、Router ID、ピア一覧、フィルタ等）**: 現状は`bgp-server.rb`内にコメントアウトされたポート定義しかなく、外部から設定を注入する手段がない。実運用にはYAML/TOML等の設定ファイルか最小限のCLI引数が必要。

### 運用要件

- **構造化ログ出力 (JSON)**: セッション状態遷移や受信UPDATEの内容を後から`jq`等で追跡できるようにし、障害時の切り分けを容易にする（未実装。Issue [#15](https://github.com/hokkai7go/bgp-server/issues/15)）。
- **メトリクスのエクスポート (Prometheus/Grafana等)**: セッション数・受信経路数・エラー数などを外形的に監視できないと、本番投入後の異常検知ができない（未実装。Issue [#14](https://github.com/hokkai7go/bgp-server/issues/14)）。
- **IPv6 / マルチプロトコル拡張 (MP-BGP, RFC 4760)**: 現行のNLRI解析はIPv4決め打ちであり、IPv6経路を交換するにはAFI/SAFIを扱うMP_REACH_NLRI/MP_UNREACH_NLRIの実装が必要（未実装。Issue [#13](https://github.com/hokkai7go/bgp-server/issues/13)）。

### 実装優先度についての補足

詳細な受け入れ基準・成功基準は `specs/001-ruby-bgp-core/spec.md` にspec-kit形式でまとめている。上記のうち「コアプロトコル要件」がなければBGPスピーカーとして名乗れないためP1、「Linuxをルータ化するために必要な要件」は本プロジェクト固有の目的達成に必須なためP1〜P2、「運用要件」は本番運用の信頼性に関わるがコア機能の後で追加してよいためP2として扱うのが妥当と考える。
