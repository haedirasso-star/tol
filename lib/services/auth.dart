part of '../main.dart';

// ═══════════════════════════════════════════════════════════════
//  FIREBASE AUTH SERVICE — إدارة مركزية للمصادقة
// ═══════════════════════════════════════════════════════════════
class AuthService {
  static final _auth   = FirebaseAuth.instance;
  static final _db     = FirebaseFirestore.instance;
  static final _google = GoogleSignIn(scopes: ['email', 'profile']);

  static String? _verificationId;
  static int?    _resendToken;
  static String  _phoneNumber = '';

  // ════════════════════════════════════════════════════════
  //  FIX 1 — isAdmin حقيقي من Firestore
  //  مستمع منفصل خفيف — لا يُسبب حلقة مفرغة
  // ════════════════════════════════════════════════════════
  static bool _isAdminCached = false;
  static StreamSubscription<DocumentSnapshot>? _adminSub;

  // Stream لإخبار الـ UI بالتغيير فوراً
  static final _adminCtrl = StreamController<bool>.broadcast();
  static Stream<bool> get adminStream => _adminCtrl.stream;

  // ── Getters ──────────────────────────────────────────────
  static User? get currentUser => _auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;
  static bool  get isAdmin     => _isAdminCached || _isAdminEmail(currentUser?.email);
  static Stream<User?> get authChanges => _auth.authStateChanges();

  /// يستمع لتغييرات is_admin/role فقط — لا يلمس الاشتراك
  static void startAdminListener(String uid) {
    _adminSub?.cancel();
    final email = currentUser?.email;
    // تحقّق إضافي: هل الإيميل مُضاف في مجموعة admins؟
    if (email != null && email.isNotEmpty) {
      _db.collection('admins').doc(email.trim().toLowerCase()).get().then((doc) {
        if (doc.exists && !_isAdminCached) {
          _isAdminCached = true;
          _adminCtrl.add(true);
          debugPrint('AuthService: isAdmin=true (admins collection)');
        }
      }).catchError((_) {});
    }
    // ★ أُزيل listener ثانٍ كان يراقب نفس المستند users/{uid}.
    //   الآن UserDataWatcher (البث الوحيد) يستدعي applyAdminFrom عند كل تغيير.
    final cached = UserDoc.peek(uid);
    if (cached != null) applyAdminFrom(cached);
  }

  /// يُستدعى من UserDataWatcher عند كل تحديث — بلا أي قراءة إضافية.
  static void applyAdminFrom(Map<String, dynamic> d) {
    final v = d['is_admin'] == true ||
              d['role']?.toString() == 'admin' ||
              _isAdminEmail(currentUser?.email) ||
              _isAdminCached; // لا تُلغِ صلاحية من مجموعة admins
    if (v != _isAdminCached) {
      _isAdminCached = v;
      _adminCtrl.add(v);
      debugPrint('AuthService: isAdmin=$v');
    }
  }

  static void stopAdminListener() {
    _adminSub?.cancel();
    _adminSub = null;
    _isAdminCached = false;
    _adminCtrl.add(false);
  }

  static bool _isAdminEmail(String? e) {
    if (e == null) return false;
    final x = e.trim().toLowerCase();
    return x.endsWith('@totv.com') ||
        x == 'admin@totv.com' ||
        x == 'haedirasso@gmail.com';
  }

  // ════════════════════════════════════════════════════════
  //  تسجيل الدخول
  // ════════════════════════════════════════════════════════
  static Future<AuthResult> signInEmail(String email, String pass) async {
    try {
      final c = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: pass.trim());
      await _trackLogin('email', c.user);
      return AuthResult.ok(c.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('حدث خطأ غير متوقع');
    }
  }

  static Future<AuthResult> registerEmail(String email, String pass, String name) async {
    try {
      final c = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: pass.trim());
      await c.user?.updateDisplayName(name.trim());
      await c.user?.reload();
      await _trackLogin('register', c.user);
      return AuthResult.ok(_auth.currentUser!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    }
  }

  static Future<AuthResult> signInGoogle() async {
    // ★ iOS: بدون إعداد Firebase للآيفون (iosClientId) يتعطّل GoogleSignIn ⇐ نمنعه برسالة واضحة
    if (Plat.isIOS && (DefaultFirebaseOptions.ios.iosClientId ?? '').isEmpty) {
      return AuthResult.err('تسجيل الدخول بجوجل غير مفعّل بعد في نسخة الآيفون — استخدم البريد الإلكتروني');
    }
    try {
      final acc = await _google.signIn();
      if (acc == null) return AuthResult.err('تم الإلغاء');
      final auth = await acc.authentication;
      final cred = GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      final uc = await _auth.signInWithCredential(cred);
      await _trackLogin('google', uc.user);
      return AuthResult.ok(uc.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل تسجيل الدخول بـ Google');
    }
  }

  static Future<AuthResult> signInFacebook() async {
    try {
      final provider = OAuthProvider('facebook.com');
      provider.addScope('email');
      provider.addScope('public_profile');
      provider.setCustomParameters({'display': 'popup'});
      UserCredential uc;
      if (kIsWeb) {
        uc = await _auth.signInWithPopup(provider);
      } else {
        uc = await _auth.signInWithProvider(provider);
      }
      await _trackLogin('facebook', uc.user);
      return AuthResult.ok(uc.user!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        return AuthResult.err('هذا البريد مرتبط بطريقة تسجيل أخرى');
      }
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل تسجيل الدخول بـ Facebook');
    }
  }

  static Future<AuthResult> sendPhoneOTP(String phone, {
    void Function(String, int?)? onCodeSent,
    void Function(PhoneAuthCredential)? onAutoVerify,
    void Function(String)? onError,
  }) async {
    if (phone.trim().isEmpty) return AuthResult.err('أدخل رقم الهاتف');
    _phoneNumber = phone.trim();
    if (!_phoneNumber.startsWith('+')) _phoneNumber = '+$_phoneNumber';
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential cred) async {
          try {
            final uc = await _auth.signInWithCredential(cred);
            await _trackLogin('phone_auto', uc.user);
            onAutoVerify?.call(cred);
          } catch (e) { debugPrint('[profile_player] $e'); }
        },
        verificationFailed: (e) => onError?.call(_msg(e.code)),
        codeSent: (vid, token) {
          _verificationId = vid;
          _resendToken    = token;
          onCodeSent?.call(vid, token);
        },
        codeAutoRetrievalTimeout: (vid) => _verificationId = vid,
      );
      return AuthResult.ok(null, msg: 'تم إرسال الكود');
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل إرسال الكود — تأكد من الرقم');
    }
  }

  static Future<AuthResult> verifyPhoneOTP(String smsCode) async {
    if (smsCode == 'AUTO') {
      final u = _auth.currentUser;
      return u != null ? AuthResult.ok(u) : AuthResult.err('فشل التحقق التلقائي');
    }
    if (_verificationId == null) return AuthResult.err('أعد إرسال الكود أولاً');
    if (smsCode.trim().length < 6) return AuthResult.err('أدخل الكود المكوّن من 6 أرقام');
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: _verificationId!, smsCode: smsCode.trim());
      final uc = await _auth.signInWithCredential(cred);
      if (uc.user?.displayName == null || uc.user!.displayName!.isEmpty) {
        await uc.user?.updateDisplayName(_phoneNumber);
        await uc.user?.reload();
      }
      await _trackLogin('phone', _auth.currentUser);
      _verificationId = null;
      return AuthResult.ok(_auth.currentUser!);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        return AuthResult.err('الكود غير صحيح — تأكد وأعد المحاولة');
      }
      return AuthResult.err(_msg(e.code));
    } catch (_) {
      return AuthResult.err('فشل التحقق — حاول مجدداً');
    }
  }

  static Future<AuthResult> resendPhoneOTP({
    void Function(String, int?)? onCodeSent,
    void Function(String)? onError,
  }) => sendPhoneOTP(_phoneNumber, onCodeSent: onCodeSent, onError: onError);

  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.ok(null, msg: 'تم إرسال رابط إعادة التعيين إلى بريدك');
    } on FirebaseAuthException catch (e) {
      return AuthResult.err(_msg(e.code));
    }
  }

  static Future<bool> updateDisplayName(String name) async {
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
      await _auth.currentUser?.reload();
      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid)
            .update({'name': name.trim()}).catchError((_) {});
      }
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> updatePhotoURL(String url) async {
    try {
      await _auth.currentUser?.updatePhotoURL(url);
      await _auth.currentUser?.reload();
      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid)
            .update({'photo': url}).catchError((_) {});
      }
      return true;
    } catch (_) { return false; }
  }

  // ════════════════════════════════════════════════════════
  //  تسجيل الخروج
  // ════════════════════════════════════════════════════════
  static Future<void> signOut() async {
    stopAdminListener();
    await _google.signOut().catchError((_) {});
    await _auth.signOut();
  }

  // ════════════════════════════════════════════════════════
  //  UPGRADED — _trackLogin يستخدم SafeUserWriter (check-then-write)
  //  يمنع التعارض ويحمي بيانات المستخدم الموجود
  // ════════════════════════════════════════════════════════
  static Future<void> _trackLogin(String method, User? user) async {
    if (user == null) return;
    try {
      final devId = await DeviceId.get();

      // ── SafeUserWriter: كتابة آمنة مع check-then-write ──
      await SafeUserWriter.writeUserData(
        uid:      user.uid,
        method:   method,
        baseData: {
          'email':        user.email         ?? '',
          'phone':        user.phoneNumber   ?? '',
          'display_name': user.displayName   ?? '',
          'name':         user.displayName   ?? '',
          'photo_url':    user.photoURL      ?? '',
          'photo':        user.photoURL      ?? '',
          'method':       method,
          'platform':     Plat.name,
          'device_id':    devId,
          'app_version':  AppVersion.version,
          'is_admin':     _isAdminEmail(user.email),
        },
      );

      // ── ابدأ مستمع الأدمن (خفيف — يقرأ فقط) ─────────────
      startAdminListener(user.uid);

      // ── ابدأ المستمع الشامل لبيانات المستخدم ─────────────
      // يستجيب فوراً لأي تغيير من لوحة الإدارة
      UserDataWatcher.startListening(user.uid);

    } catch (e) {
      debugPrint('AuthService._trackLogin error: $e');
    }
  }

  static String _msg(String code) {
    const m = {
      'user-not-found':            'البريد الإلكتروني غير مسجّل',
      'wrong-password':            'كلمة المرور غير صحيحة',
      'invalid-credential':        'البيانات غير صحيحة',
      'email-already-in-use':      'البريد مسجّل مسبقاً',
      'weak-password':             'كلمة المرور ضعيفة (6 أحرف على الأقل)',
      'invalid-email':             'البريد الإلكتروني غير صالح',
      'too-many-requests':         'محاولات كثيرة — انتظر قليلاً',
      'network-request-failed':    'تحقق من اتصالك بالإنترنت',
      'user-disabled':             'تم تعطيل هذا الحساب',
      'invalid-phone-number':      'رقم الهاتف غير صالح',
      'quota-exceeded':            'تم تجاوز الحد — حاول لاحقاً',
      'invalid-verification-code': 'كود التحقق غير صحيح',
      'session-expired':           'انتهت صلاحية الكود — أعد الإرسال',
    };
    return m[code] ?? 'خطأ: $code';
  }
}

// ════════════════════════════════════════════════════════════════
//  AdminAwareBuilder — يُعيد البناء فوراً عند تغيير is_admin
//  استخدمه بدلاً من if(AuthService.isAdmin) في الـ build()
// ════════════════════════════════════════════════════════════════
class AdminAwareBuilder extends StatelessWidget {
  final Widget Function(bool isAdmin) builder;
  const AdminAwareBuilder({required this.builder, super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: AuthService.adminStream,
    initialData: AuthService.isAdmin,
    builder: (_, snap) => builder(snap.data ?? false),
  );
}

class AuthResult {
  final bool   ok;
  final User?  user;
  final String msg;
  const AuthResult._(this.ok, this.user, this.msg);
  factory AuthResult.ok(User? u, {String msg = ''}) => AuthResult._(true, u, msg);
  factory AuthResult.err(String msg) => AuthResult._(false, null, msg);
}
