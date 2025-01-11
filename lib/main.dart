import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ontrack',
      home: OnTrackHome(),
    );
  }
}

class OnTrackHome extends StatefulWidget {
  @override
  _OnTrackHomeState createState() => _OnTrackHomeState();
}

class _OnTrackHomeState extends State<OnTrackHome> {
  bool isRiding = false;
  bool isPaused = false;
  bool hasPrepaid = false;
  double prepaidAmount = 0.0;
  Duration prepaidDuration = Duration.zero;
  DateTime? startTime;
  Timer? timer;
  Duration rideDuration = Duration.zero;
  String nearestParking = '조회 중...';

  final List<Map<String, dynamic>> parkingLocations = [
    {'name': '건국대학교 공학관 A동 앞 주차장', 'latitude': 37.5401, 'longitude': 127.0796},
    {'name': '건국대학교 운동장 앞 주차장', 'latitude': 37.5415, 'longitude': 127.0812}
  ];

  @override
  void initState() {
    super.initState();
    _loadStateFromDB();
    _getNearestParking();
  }

  Future<void> _loadStateFromDB() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isRiding = prefs.getBool('isRiding') ?? false;
      isPaused = prefs.getBool('isPaused') ?? false;
      prepaidAmount = prefs.getDouble('prepaidAmount') ?? 0.0;
      int durationInSeconds = prefs.getInt('rideDuration') ?? 0;
      rideDuration = Duration(seconds: durationInSeconds);
    });
  }

  Future<void> _saveStateToDB() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isRiding', isRiding);
    prefs.setBool('isPaused', isPaused);
    prefs.setDouble('prepaidAmount', prepaidAmount);
    prefs.setInt('rideDuration', rideDuration.inSeconds);
  }

  Future<void> _getNearestParking() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double userLatitude = position.latitude;
      double userLongitude = position.longitude;

      Map<String, dynamic>? nearest = _findNearestParking(userLatitude, userLongitude);

      setState(() {
        nearestParking = nearest != null
            ? '가까운 주차장: ${nearest['name']} (${_calculateDistance(userLatitude, userLongitude, nearest['latitude'], nearest['longitude']).toStringAsFixed(1)}m)'
            : '주변에 주차장을 찾을 수 없습니다.';
      });
    } catch (e) {
      setState(() {
        nearestParking = '위치 정보를 가져오는 데 실패했습니다.';
      });
    }
  }

  Map<String, dynamic>? _findNearestParking(double userLat, double userLon) {
    Map<String, dynamic>? nearest;
    double minDistance = double.infinity;

    for (var parking in parkingLocations) {
      double distance = _calculateDistance(userLat, userLon, parking['latitude'], parking['longitude']);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = parking;
      }
    }

    return nearest;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // in meters
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) + math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * (math.sin(dLon / 2) * math.sin(dLon / 2));
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.141592653589793 / 180);
  }

  void startRideFlow() {
    _showPrepayDialog();
  }

  void startRide({bool isDebug = false}) {
    setState(() {
      isRiding = true;
      isPaused = false;
      startTime = DateTime.now();
      rideDuration = Duration.zero;
    });

    if (!isDebug) {
      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          rideDuration = DateTime.now().difference(startTime!);
        });
        _saveStateToDB();
      });
    } else {
      // 디버깅 모드일 때 가상 데이터로 시작
      rideDuration = Duration(minutes: 10); // 가상으로 10분 설정
      _saveStateToDB();
    }
  }

  void pauseRide() {
    if (isRiding) {
      timer?.cancel();
      setState(() {
        isPaused = true;
        isRiding = false;
      });
      _saveStateToDB();
    }
  }

  void resumeRide() async {
    final qrResult = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => QRScanPage(debugMode: false)),
    );

    if (qrResult != null) {
      setState(() {
        isRiding = true;
        isPaused = false;
        startTime = DateTime.now().subtract(rideDuration);
      });

      timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          rideDuration = DateTime.now().difference(startTime!);
        });
        _saveStateToDB();
      });
    }
  }

  void stopRide() {
    if (isRiding && startTime != null) {
      timer?.cancel();
      DateTime endTime = DateTime.now();
      Duration totalTime = endTime.difference(startTime!);

      double discount = _getDiscountBasedOnDensity();
      double refund = prepaidAmount * discount;

      setState(() {
        isRiding = false;
        hasPrepaid = false;
        startTime = null;
        rideDuration = Duration.zero;
      });

      _showRefundDialog(refund);
      _saveStateToDB();
    }
  }

  void _showPrepayDialog() {
    int selectedMinutes = 10;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용 시간 사전 결제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '직접 입력 (분)'),
              onChanged: (value) {
                int minutes = int.tryParse(value) ?? 0;
                setState(() {
                  selectedMinutes = minutes;
                });
              },
            ),
            SizedBox(height: 10),
            DropdownButton<int>(
              value: selectedMinutes,
              items: [10, 20, 30, 60].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value 분'),
                );
              }).toList(),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    selectedMinutes = value;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                prepaidDuration = Duration(minutes: selectedMinutes);
                prepaidAmount = selectedMinutes * 100.0; // 분당 100원 요금
                hasPrepaid = true;
              });
              Navigator.pop(context);
              _showPaymentDialog();
            },
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('결제 수단 선택'),
        content: Text('결제 수단을 선택하세요.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRScanPage(debugMode: false)),
              ).then((_) => startRide());
            },
            child: Text('카드 결제'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRScanPage(debugMode: false)),
              ).then((_) => startRide());
            },
            child: Text('계좌 이체'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRScanPage(debugMode: true)),
              ).then((_) => startRide(isDebug: true));
            },
            child: Text('디버깅'),
          ),
        ],
      ),
    );
  }

  void _showRefundDialog(double refund) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('환불 정보'),
        content: Text('할인된 금액으로 ₩${refund.toStringAsFixed(2)} 환불됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  double _getDiscountBasedOnDensity() {
    // 임시 밀집도에 따른 할인율 (0% ~ 20%)
    int density = 50; // 가상 밀집도 값 (0~100)
    return (density / 100) * 0.2;
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('ONTRACK'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 50,
            right: 50,
            top: 100,
          ),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.directions_bike,
                size: 40,
              ),
              Center(
                child: Text(
                  '온트랙 서비스',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 40),
              Text(
                nearestParking,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 40),
              if (isRiding)
                Text(
                  '이용 시간: ${formatDuration(rideDuration)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isRiding ? null : startRideFlow,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text('사용 시작'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: isRiding ? stopRide : null,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text('사용 종료'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: isRiding ? pauseRide : null,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text(isPaused ? '재사용' : '중지'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QRScanPage extends StatefulWidget {
  final bool debugMode;
  QRScanPage({required this.debugMode});

  @override
  _QRScanPageState createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String? qrResult;

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('QR 코드 스캔'),
        actions: [
          if (widget.debugMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'DEBUG-DATA');
              },
              child: Text(
                '디버깅',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: (qrResult != null)
                  ? Text('QR 코드 결과: $qrResult')
                  : Text('QR 코드를 스캔하세요.'),
            ),
          )
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      setState(() {
        qrResult = scanData.code;
      });
      Navigator.pop(context, qrResult);
    });
  }
}
