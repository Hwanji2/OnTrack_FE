import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
  DateTime? startTime;
  int selectedMinutes = 10; // 선택된 시간을 저장하는 변수

  bool hasPrepaid = false;
  double prepaidAmount = 0.0;
  Duration prepaidDuration = Duration.zero;
  Duration remainingDuration = Duration.zero;
  Timer? timer;
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
      int durationInSeconds = prefs.getInt('remainingDuration') ?? 0;
      remainingDuration = Duration(seconds: durationInSeconds);
    });
  }

  Future<void> _saveStateToDB() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isRiding', isRiding);
    prefs.setBool('isPaused', isPaused);
    prefs.setDouble('prepaidAmount', prepaidAmount);
    prefs.setInt('remainingDuration', remainingDuration.inSeconds);
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
      remainingDuration = prepaidDuration;
    });

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingDuration > Duration.zero) {
          remainingDuration -= Duration(seconds: 1);
        } else {
          stopRide();
          timer.cancel();
        }
      });
      _saveStateToDB();
    });
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

  void resumeRide() {
    setState(() {
      isPaused = false;
      isRiding = true;
    });

    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingDuration > Duration.zero) {
          remainingDuration -= Duration(seconds: 1);
        } else {
          stopRide();
          timer.cancel();
        }
      });
      _saveStateToDB();
    });
  }

  void stopRide() {
    if (startTime != null) {
      setState(() {
        remainingDuration = prepaidDuration - DateTime.now().difference(startTime!);
      });
    }

    timer?.cancel();
    double discount = _getDiscountBasedOnDensity();
    double discountedAmount = prepaidAmount * (1 - discount);
    double remainingRefund = (discountedAmount / prepaidDuration.inSeconds) * remainingDuration.inSeconds;
    double totalRefund = remainingRefund;

    setState(() {
      isRiding = false;
      hasPrepaid = false;
      startTime = null;
    });

    _showRefundDialog(totalRefund, discountedAmount);
    _saveStateToDB();
  }

  void _showPrepayDialog() {
    setState(() {
      selectedMinutes = prepaidDuration.inMinutes > 0 ? prepaidDuration.inMinutes : 10;
    });

    TextEditingController textController = TextEditingController(text: selectedMinutes.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('사용 시간 사전 결제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '직접 입력 (분)'),
              onChanged: (value) {
                int minutes = int.tryParse(value) ?? 0;
                setState(() {
                  selectedMinutes = minutes > 0 ? minutes : 10;
                });
              },
            ),
            SizedBox(height: 10),
            DropdownButton<int>(
              hint: Text('시간 선택'), // 기본으로 보이는 텍스트
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
                    textController.text = value.toString(); // 드롭다운 선택 시 TextField도 동기화
                  });
                }
              },
            ),
            SizedBox(height: 20),
            Text(
              '분산된 주차장에 주차할 시 할인이 적용되며, 사용 시간이 남을 경우 금액을 환불받을 수 있습니다.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
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
        content: Text('총 결제 금액: ₩${prepaidAmount.toStringAsFixed(2)}'),
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

  void _showRefundDialog(double refund, double discountedAmount) async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    double discountRate = _getDiscountBasedOnDensity() * 100;
    String formattedTotalDuration = formatDuration(prepaidDuration);
    String formattedRemainingDuration = formatDuration(remainingDuration);
    Map<String, dynamic>? nearest = _findNearestParking(position.latitude, position.longitude);
    double distanceToParking = nearest != null
        ? _calculateDistance(position.latitude, position.longitude, nearest['latitude'], nearest['longitude'])
        : double.infinity;

    double remainingRefund = (discountedAmount / prepaidDuration.inSeconds) * remainingDuration.inSeconds;
    double totalRefund = remainingRefund;
    double totalPaid = discountedAmount - refund;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Center(
          child: Text(
            '환불 정보',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('결제한 사용 시간', formattedTotalDuration),
            SizedBox(height: 10),
            _buildInfoRow('남은 시간', formattedRemainingDuration),
            SizedBox(height: 10),
            _buildInfoRow('가까운 주차장', nearest?['name'] ?? '없음'),
            SizedBox(height: 10),
            _buildInfoRow('주차장 거리', '${distanceToParking.toStringAsFixed(1)}m'),
            SizedBox(height: 10),
            _buildInfoRow('현재 위치', '(${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})'),
            SizedBox(height: 10),
            _buildInfoRow('밀집도', '50%'),
            SizedBox(height: 10),
            _buildInfoRow('할인율', '${discountRate.toStringAsFixed(1)}%'),
            SizedBox(height: 10),
            _buildInfoRow('총 환불 금액', '₩${totalRefund.toStringAsFixed(2)}'),
            SizedBox(height: 10),
            _buildInfoRow('총 지불한 금액', '₩${totalPaid.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '확인',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
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
                  '이용 시간: ${formatDuration(remainingDuration)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 80),
              ElevatedButton(
                onPressed: isRiding ? pauseRide : (isPaused ? resumeRide : startRideFlow),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text(isPaused ? '재사용' : (isRiding ? '사용 중지' : '사용 시작')),
              ),
              SizedBox(height: 15),
              ElevatedButton(
                onPressed: isRiding ? stopRide : null,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text('사용 종료'),
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
