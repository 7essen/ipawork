import 'package:fcmyoutube/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';


class FirebaseApi {
  final _firebseMessaging = FirebaseMessaging.instance;


  Future<void> initNotification ()async{
    await _firebseMessaging.requestPermission();
    String? token = await _firebseMessaging.getToken();
    print("token: $token");

  }
  void HandleMessage(RemoteMessage? message){
    if (message == Null) return;
    navigatorKey.currentState?.pushNamed(
      '/notification_screen',
      arguments: message,
    );
  }
  Future initPushNotification() async{
    FirebaseMessaging.instance.getInitialMessage().then(HandleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(HandleMessage);
  }
}
