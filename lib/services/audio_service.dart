import 'package:folds/state/app_settings.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:folds/state/app_store.dart';


class AudioService {
  static final AudioPlayer _music = AudioPlayer();
  static final AudioPlayer _sfx = AudioPlayer();
  static bool _initialized = false;

  static Future<void> init() async {
  if (_initialized) return;
  _initialized = true;
  AppSettings.sfxVolume = AppStore.sfxVolume;
  AppSettings.musicVolume = AppStore.musicVolume;
  await _music.setReleaseMode(ReleaseMode.loop);
  await _music.setVolume(AppSettings.musicVolume);
  await _sfx.setVolume(AppSettings.sfxVolume);
}
  
  // static Future<void> startMusic() async {
  //  if (!AppSettings.musicEnabled) return;
  //  await _music.play(AssetSource('sounds/bgm.mp3'));
  // }

  static Future<void> stopMusic() async => await _music.stop();
  static Future<void> pauseMusic() async => await _music.pause();
  static Future<void> resumeMusic() async {
    if (AppSettings.musicEnabled) await _music.resume();
  }

  static Future<void> flip() async {
    if (!AppSettings.sfxEnabled) return;
    // Create a new short-lived player each time so overlapping flips all fire
    final p = AudioPlayer();
    await p.setVolume(AppSettings.sfxVolume);
    await p.play(AssetSource('sounds/flip.mp3'));
    p.onPlayerComplete.listen((_) => p.dispose());
  }
  

  static Future<void> solve() async {
    if (!AppSettings.sfxEnabled) return;
    await _sfx.play(AssetSource('sounds/solve.mp3'));
  }

  static void setMusicVolume(double v) {
  AppSettings.musicVolume = v;
  AppStore.musicVolume = v;
  _music.setVolume(v);
}

static void setSfxVolume(double v) {
  AppSettings.sfxVolume = v;
  AppStore.sfxVolume = v;
  _sfx.setVolume(v);
}
}