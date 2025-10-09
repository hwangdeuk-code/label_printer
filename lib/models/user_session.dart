// UTF-8, 한국어 주석

/// 로그인 후 유지되는 사용자 세션 정보
class UserSession {
  /// 아이디
  final String id;

  /// 사용자 이름
  final String userName;

  /// 업체명
  final String companyName;

  /// 지점명
  final String branchName;

  const UserSession({
    required this.id,
    required this.userName,
    required this.companyName,
    required this.branchName,
  });
}