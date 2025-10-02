import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:usage_stats/usage_stats.dart'; // usage_statsプラグインをインポート

// UsageEventクラスの定義（変更なし）
class UsageEvent {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Duration duration;
  final DateTime timestamp;

  UsageEvent({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.duration,
    required this.timestamp,
  });
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Timeline Prototype',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF2D2F41),
      ),
      home: const UsageLogScreen(),
    );
  }
}

class UsageLogScreen extends StatefulWidget {
  const UsageLogScreen({super.key});

  @override
  State<UsageLogScreen> createState() => _UsageLogScreenState();
}

class _UsageLogScreenState extends State<UsageLogScreen> {
  // --- ここからが追加・変更部分 ---

  List<UsageEvent> _events = []; // 表示するイベントリスト
  bool _isLoading = true; // 読み込み状態を管理

  @override
  void initState() {
    super.initState();
    _loadUsageData(); // アプリ起動時にデータを読み込む
  }
  
  // あなたが見つけてくれたロジックを組み込んだ、データ取得メソッド
  Future<void> _loadUsageData() async {
    // 1. 権限の確認と要求
    bool isPermission = await UsageStats.checkUsagePermission() ?? false;
    if (!isPermission) {
      // 権限がない場合は設定画面に遷移する
      UsageStats.grantUsagePermission();
      // この時点ではデータ取得はできないので一旦処理を終了
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 2. データの取得
    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day); // 今日の0時

      // イベントリストを取得
      List<EventUsageInfo> rawEvents = await UsageStats.queryEvents(startDate, endDate);

      // 3. 取得した生データをUIで使えるUsageEventに変換
      List<UsageEvent> newEvents = [];
      // イベントをタイムスタンプの降順（新しいものが先）にソート
      rawEvents.sort((a, b) => b.timeStamp!.compareTo(a.timeStamp!));

      for (int i = 0; i < rawEvents.length; i++) {
        final current = rawEvents[i];
        Duration duration;

        // 各イベントの継続時間を計算（次のイベントが起きるまでの時間）
        if (i + 1 < rawEvents.length) {
          final previous = rawEvents[i + 1];
          duration = Duration(
            milliseconds: int.parse(current.timeStamp!) - int.parse(previous.timeStamp!)
          );
        } else {
          // リストの最後のイベントは継続時間0とする
          duration = Duration.zero;
        }

        final appInfo = _getAppIconInfo(current.packageName!);

        newEvents.add(
          UsageEvent(
            title: appInfo['name'], // パッケージ名からアプリ名を取得
            icon: appInfo['icon'],
            iconColor: appInfo['color'],
            duration: duration,
            timestamp: DateTime.fromMillisecondsSinceEpoch(int.parse(current.timeStamp!)),
          ),
        );
      }
      
      setState(() {
        _events = newEvents;
        _isLoading = false;
      });

    } catch (err) {
      // エラーハンドリング
      debugPrint(err.toString());
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // パッケージ名に応じて表示名やアイコンを返すヘルパー関数
  Map<String, dynamic> _getAppIconInfo(String packageName) {
    if (packageName.contains('instagram')) {
      return {'name': 'Instagram', 'icon': Icons.camera_alt, 'color': Colors.pink};
    }
    if (packageName.contains('youtube')) {
      return {'name': 'YouTube', 'icon': Icons.play_arrow, 'color': Colors.red};
    }
    if (packageName.contains('chrome')) {
      return {'name': 'Chrome', 'icon': Icons.web, 'color': Colors.green};
    }
    if (packageName.contains('twitter') || packageName.contains('x.android')) {
      return {'name': 'X (Twitter)', 'icon': Icons.close, 'color': Colors.white};
    }
    // ここでは画面ロックなどもパッケージ名として取得されることがある
    // eventTypeを見て判定するのがより正確
    if (packageName == 'android') {
      return {'name': 'システムイベント', 'icon': Icons.android, 'color': Colors.grey};
    }
    return {'name': packageName, 'icon': Icons.app_blocking, 'color': Colors.grey};
  }
  
  // --- ここまでが追加・変更部分 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用ログ（実際データ）'),
        backgroundColor: const Color(0xFF2D2F41),
        elevation: 1,
      ),
      // データを読み込み中か、データが空かで表示を切り替える
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? Center(
                  child: Text(
                    'データがありません。\n権限を許可してください。',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return TimelineTile(
                      alignment: TimelineAlign.manual,
                      lineXY: 0.2,
                      isFirst: index == 0,
                      isLast: index == _events.length - 1,
                      beforeLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
                      afterLineStyle: const LineStyle(color: Colors.white54, thickness: 2),
                      indicatorStyle: IndicatorStyle(
                        width: 15,
                        color: Colors.white54,
                        padding: const EdgeInsets.all(4),
                      ),
                      startChild: Text(
                        DateFormat('HH:mm:ss').format(event.timestamp),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      endChild: _buildEventDetails(event),
                    );
                  },
                ),
      // 更新ボタンを追加
      floatingActionButton: FloatingActionButton(
        onPressed: _loadUsageData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  // --- 以下のメソッドは変更なし ---
  Widget _buildEventDetails(UsageEvent event) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(event.icon, color: event.iconColor, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(event.duration),
                  style: TextStyle(color: Colors.lightGreenAccent[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '一瞬'; // 0秒以下の場合は「一瞬」と表示
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    String result = '';
    if (minutes > 0) {
      result += '$minutes分 ';
    }
    result += '$seconds秒';
    return result;
  }
}