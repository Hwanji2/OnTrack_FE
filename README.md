# 공유 킥보드 밀집도에 따른 기본요금 할인율 시스템

![image](https://github.com/user-attachments/assets/327b714e-8c85-4bc6-8756-0acfa3483c5d)![image](https://github.com/user-attachments/assets/9a1bf3a0-2026-4509-9c49-68ca7c1d09eb)

## 작품 개요
길거리를 걷다가 겹겹이 쌓인 킥보드 때문에 불편했던 적이 있으신가요?  
2018년 국내 최초 전동킥보드 공유 서비스 '킥고잉'이 등장한 이래, 다양한 공유 킥보드 서비스가 출시되면서 도시 곳곳에서 편리하게 이용할 수 있게 되었습니다. 그러나 공유 킥보드의 자율성으로 인해 주요 지하철역 주변과 보행로, 공공시설 등에서 통행 및 시설 이용을 방해하는 문제가 빈번히 발생하고 있습니다.



저희 온트랙 팀은 이러한 문제를 해결하기 위해 **밀집도 기반 기본요금 할인율 시스템**을 고안했습니다. 이 시스템은 공유 킥보드가 밀집된 지역에서의 사용을 장려하여 킥보드를 자발적으로 분산시키고, 사회적 혼란을 줄이며 지속 가능한 모빌리티 환경을 조성하는 것을 목표로 합니다.


![image](https://github.com/user-attachments/assets/9e50d9c9-da1c-40f5-8e4a-9cd7ba12c78e)

![image](https://github.com/user-attachments/assets/b1508c8f-1dfc-4691-bf67-856b0793853c)

## 주요 기능

### 1. 밀집도 기반 기본요금 할인 시스템
- 사용자가 공유 킥보드를 종료할 때, 해당 킥보드의 위치 정보를 서버로 전송합니다.
- 서버는 주변 30m 반경 내에 있는 킥보드 수를 계산하여 밀집도를 측정합니다.
- 밀집도에 따라 5대당 1원의 할인율을 적용하여 기본 요금(1500원)을 할인합니다.
- 사용자는 QR 코드를 인식한 시점에 할인된 요금을 실시간으로 확인할 수 있습니다.

### 2. 실시간 위치 정보 처리
- NEO-6M GPS 모듈과 Raspberry Pi를 사용하여 실시간으로 킥보드의 위치를 수집하고 서버에 전송합니다.
- 서버는 수신한 위치 정보를 MySQL 데이터베이스에 저장하고, 주변 킥보드 수를 계산합니다.
- ![image](https://github.com/user-attachments/assets/0eae6780-8d45-4e9c-aaf8-b0c3cddf74e4)


### 3. 사용자 인터페이스 (모바일 앱)
- Flutter로 제작된 모바일 앱은 사용자에게 할인된 요금을 실시간으로 제공하며 QR 코드 스캔을 통해 간편하게 결제할 수 있습니다.

## 전체 시스템 구성

### 동작 과정

![image](https://github.com/user-attachments/assets/0d30ab22-a0d4-4ebb-be42-4834d11be4d7)
#### 1) 사용자가 킥보드 사용 종료 시
1. NEO-6M GPS 모듈이 라즈베리 파이의 `/dev/ttyAMA0` 파일에 위도, 경도 데이터를 저장합니다.
2. 파이썬의 `pynmea2` 라이브러리를 사용하여 위치 데이터를 파싱합니다.
3. 파싱한 데이터를 `requests` 라이브러리를 이용하여 서버로 전송합니다.
4. 서버는 수신한 데이터를 MySQL 데이터베이스에 저장합니다.

#### 2) 사용자가 킥보드를 사용 시작할 때
1. 사용자가 앱에서 QR 코드를 스캔하여 킥보드 ID를 서버로 전송합니다.
2. 서버는 해당 ID로 데이터베이스에서 킥보드 위치 정보를 조회합니다.
3. 반경 30m 내의 킥보드 수를 계산하고, 할인율을 적용한 요금을 반환합니다.
4. 앱은 사용자에게 할인된 요금을 표시합니다.

## 개발 환경

### 하드웨어
- **Raspberry Pi**: 킥보드 시뮬레이션 장치
- **NEO-6M GPS 모듈**: 실시간 위치 정보 수집

### 소프트웨어
- **서버**: Java Spring Boot
- **데이터베이스**: MySQL
- **프론트엔드 앱**: Flutter
- **통신**: HTTP 프로토콜을 통한 클라이언트-서버 간 데이터 전송
- **파이썬**: 위치 데이터 파싱 및 서버 통신
- ![image](https://github.com/user-attachments/assets/e68a7d42-d800-48b3-8e6b-7d6445cf50e8)


## 단계별 제작 과정


![image](https://github.com/user-attachments/assets/446b73d3-662d-4e46-8cf4-df9350d3b5f5)

### 1. 아이디어 선정 및 구체화 (3월 1일 ~ 3월 5일)
- 온라인 회의를 통해 여러 아이디어를 논의하고, 공유 킥보드 밀집 문제 해결 아이디어를 선정하였습니다.
- 대면 회의를 통해 구체적인 시스템 설계 및 사용 기술을 결정하였습니다.

### 2. 서버 구축 (3월 5일 ~ 3월 14일)
- Java Spring Boot를 이용하여 서버의 기본 구조를 구축하였습니다.
- MySQL 데이터베이스를 설계하고 DataGrip을 사용하여 테이블을 생성했습니다.
- 두 가지 주요 API를 구현하였습니다:
  1. 킥보드 정보를 수신하여 저장하는 API
  2. 주변 킥보드 수를 계산하고 할인된 요금을 반환하는 API

### 3. 하드웨어 제작 (3월 11일 ~ 3월 15일)
- Raspberry Pi에 라즈베리 파이 OS를 설치하고 초기 환경 설정을 완료했습니다.
- NEO-6M GPS 모듈과 Raspberry Pi를 연결하고, 회로도를 작성하여 하드웨어를 구성했습니다.
- NEO-6M 모듈에서 GPS 데이터를 수신하고 이를 라즈베리 파이로 전송하는 작업을 완료했습니다.


![image](https://github.com/user-attachments/assets/893098d5-1194-40dd-8a5a-7c9115951034)


### 4. 하드웨어-서버 통신 테스트 (3월 21일)
- 라즈베리 파이에서 수집한 위치 데이터를 서버로 전송하고, 서버가 데이터를 정확하게 처리하는지 검증했습니다.
- 테스트 결과, 실내에서는 GPS 신호가 약하여 외부 환경에서 테스트를 진행하였고 정상적으로 작동하는 것을 확인했습니다.

![image](https://github.com/user-attachments/assets/c692209a-6615-40f6-9da7-e10d37f9fe02)

### 5. 앱 개발 (3월 22일 ~ 3월 25일)
- Flutter로 모바일 앱을 개발하였으며, 서버로부터 데이터를 수신하여 사용자에게 요금을 표시하는 기능을 구현했습니다.

[![실행 화면](https://youtu.be/yJf9vM9OTJ8?feature=shared)

### 6. 최종 테스트 및 시연 (3월 26일)
- 완성된 하드웨어, 서버, 앱을 통합하여 실제로 작동하는 환경을 시뮬레이션하였습니다.
- 프로젝트 결과물을 공유 킥보드에 장착하고 테스트를 진행하여 아이디어의 실현 가능성을 검증했습니다.

## 사용한 제품 리스트
- **NEO-6M GPS 모듈 GY-GPS6MV2**
  - [제품 링크](https://www.devicemart.co.kr/goods/view?no=1321968)
- **Raspberry Pi**
  - [제품 링크](https://www.devicemart.co.kr/goods/view?no=1311414)

## 회로도
- 프로젝트에 사용한 회로도는 아래와 같습니다:
![image](https://github.com/user-attachments/assets/f858d756-2d6d-4489-b650-1704e85693c6)

  

## 소스코드
- **서버**: [GitHub Repository - On-Track Server](https://github.com/imscow11253/on-Track)
- **프론트 앱**: 현재 레포지토리
- **파이썬 코드**: [GitHub Repository - On-Track Python](https://github.com/imscow11253/on-Track)

## 참고 문헌
- [Use Neo 6M GPS Module with Raspberry Pi and Python](https://sparklers-the-makers.github.io)
- [Raspberry Pi 의 GPIO 사용해보기 - 네이버 블로그](https://naver.com)




# ONTRACK

ONTRACK_FE는 스마트 사전 결제, 가까운 주차장 조회, 실시간 사용 시간 추적 등 편리한 자전거 공유 서비스를 제공하는 Flutter 기반 모바일 애플리케이션입니다.

## 주요 기능

### 1. 사전 결제 관리
- 사용자는 원하는 사용 시간을 선택하여 사전 결제할 수 있습니다.
- 남은 시간이 실시간으로 표시되며, 사용 종료 시 남은 시간에 따라 환불 금액이 자동 계산됩니다.
- 밀집도에 따라 할인율이 적용되어 특정 주차장 이용 시 추가 할인을 받을 수 있습니다.

### 2. 가까운 주차장 조회
- **Geolocator** 패키지를 활용하여 사용자의 현재 위치를 기반으로 가장 가까운 주차장을 탐색합니다.
- 주차장과의 거리 및 위치 정보를 실시간으로 제공합니다.
- 현재 지원하는 주차장 목록:
  - 건국대학교 공학관 A동 앞 주차장
  - 건국대학교 운동장 앞 주차장

### 3. QR 코드 결제
- QR 코드를 통해 결제 및 라이딩 시작이 가능합니다.
- 디버깅 모드에서 QR 코드 없이 테스트 진행이 가능합니다.

### 4. 타이머 기반 라이딩 관리
- 사전 결제한 시간에 따라 타이머가 작동하며, 실시간으로 남은 시간이 표시됩니다.
- **사용 시작**, **일시 정지**, **재사용**, **종료** 기능을 지원합니다.
- 라이딩 종료 시, 남은 시간에 따른 환불 금액 및 할인 금액을 자동 계산하여 사용자에게 표시합니다.

## 기술 스택

- **Flutter**: UI 및 전체 애플리케이션 구조 개발
- **Dart**: Flutter 애플리케이션의 주 프로그래밍 언어
- **Geolocator**: 위치 정보를 가져와 가까운 주차장을 계산
- **Shared Preferences**: 상태 데이터를 로컬에 저장하여 앱 종료 후에도 상태 복원 가능
- **QR Code Scanner**: QR 코드 기반 결제 및 디버깅 지원

## 앱 사용 방법

1. **앱 실행**
   - 앱을 실행하면 자동으로 가장 가까운 주차장을 탐색하여 화면에 표시합니다.

2. **사전 결제**
   - '사용 시작' 버튼을 눌러 사전 결제 창을 띄웁니다.
   - 원하는 사용 시간을 입력하거나 드롭다운에서 선택하여 사전 결제를 진행합니다.
   - 결제 금액이 표시되며, QR 코드 스캔을 통해 결제가 완료됩니다.

3. **라이딩 시작**
   - 결제 후 타이머가 시작되며, 실시간으로 남은 시간이 표시됩니다.

4. **일시 정지 및 재사용**
   - 라이딩 도중 일시 정지할 수 있으며, 필요 시 '재사용' 버튼을 눌러 다시 시작할 수 있습니다.

5. **라이딩 종료 및 환불**
   - 사용 종료 시 남은 시간에 따른 환불 금액이 계산되어 화면에 표시됩니다.
   - 밀집도에 따른 할인율이 적용된 환불 금액이 함께 표시됩니다.

## 설치 방법

1. 이 저장소를 클론합니다.
   ```bash
   git clone https://github.com/사용자명/ontrack.git
   cd ontrack
Flutter 환경을 설정한 후 의존성을 설치합니다.
bash
코드 복사
flutter pub get
디바이스 또는 에뮬레이터에서 앱을 실행합니다.
bash
코드 복사
flutter run
