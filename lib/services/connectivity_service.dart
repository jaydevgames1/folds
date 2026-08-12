import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  
  static Stream<bool> get onStatuschange =>
    _connectivity.onConnectivityChanged.map((r) => !r.contains(ConnectivityResult.none));
  
  static Future<bool> get isOnline async{
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

}