/// أخطاء الميزة — لا استثناءات تعبر حدود الطبقات
abstract class Failure {
  final String message;
  const Failure(this.message);
  @override
  String toString() => message;
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.m = 'إذن المايكروفون مرفوض']);
}

class TokenFailure extends Failure {
  const TokenFailure([super.m = 'تعذّر الحصول على صلاحية دخول الغرفة']);
}

class ConnectionFailure extends Failure {
  const ConnectionFailure([super.m = 'فشل الاتصال بالغرفة']);
}

class NotAllowedFailure extends Failure {
  const NotAllowedFailure([super.m = 'لا تملك صلاحية هذا الإجراء']);
}

class RoomFailure extends Failure {
  const RoomFailure([super.m = 'خطأ في الغرفة']);
}
