// UTF-8, 한국어 주석
/// 로그인/로그아웃 이력 레코드 모델
class LoginEvent {
  final String userId;
  final String userGrade;
  final DateTime timestamp;
  final String action; // '로그인' or '로그아웃'
  final String ip;
  final String companyName;
  final String programVersion;

  const LoginEvent({
    required this.userId,
    required this.userGrade,
    required this.timestamp,
    required this.action,
    required this.ip,
    required this.companyName,
    required this.programVersion,
  });
}
