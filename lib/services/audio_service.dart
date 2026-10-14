import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight audio helper with a persistent mute toggle.
class AudioService {
  AudioService({
    this._prefs,
    AudioPlayer? sfxPlayer,
    AudioPlayer? musicPlayer,
    AudioPlayer? gameOverPlayer,
  }) : _sfx = sfxPlayer ?? AudioPlayer(),
       _music = musicPlayer ?? AudioPlayer(),
       _gameOver = gameOverPlayer ?? AudioPlayer();

  static const _muteKey = 'tap_dodge_muted';

  SharedPreferences? _prefs;
  final AudioPlayer _sfx;
  final AudioPlayer _music;
  final AudioPlayer _gameOver;

  bool _muted = false;
  bool _initialized = false;
  bool _playersConfigured = false;
  bool _musicStarted = false;

  bool get isMuted => _muted;

  Future<void> init() async {
    if (_initialized) return;
    _prefs ??= await SharedPreferences.getInstance();
    _muted = _prefs!.getBool(_muteKey) ?? false;
    _initialized = true;
  }

  Future<void> _ensurePlayersConfigured() async {
    if (_playersConfigured) return;
    try {
      await _sfx.setReleaseMode(ReleaseMode.stop);
      await _gameOver.setReleaseMode(ReleaseMode.stop);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.28);
      await _sfx.setVolume(0.85);
      await _gameOver.setVolume(1.0);
      _playersConfigured = true;
    } catch (_) {
      // Platform audio may be unavailable in tests / some devices.
    }
  }

  Future<void> setMuted(bool muted) async {
    await init();
    _muted = muted;
    await _prefs!.setBool(_muteKey, muted);
    if (muted) {
      await stopMusic();
      try {
        await _gameOver.stop();
      } catch (_) {}
    } else {
      await startMusic();
    }
  }

  Future<void> toggleMute() => setMuted(!_muted);

  Future<void> startMusic() async {
    await init();
    if (_muted || _musicStarted) return;
    try {
      await _ensurePlayersConfigured();
      await _music.play(AssetSource('audio/bgm.wav'));
      _musicStarted = true;
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {}
    _musicStarted = false;
  }

  Future<void> pauseMusic() async {
    if (!_musicStarted) return;
    try {
      await _music.pause();
    } catch (_) {}
  }

  Future<void> resumeMusic() async {
    await init();
    if (_muted) return;
    try {
      if (_musicStarted) {
        await _music.resume();
      } else {
        await startMusic();
      }
    } catch (_) {}
  }

  Future<void> playCoin() => _playSfx('audio/coin.wav');
  Future<void> playHit() => _playSfx('audio/hit.wav');
  Future<void> playClick() => _playSfx('audio/click.wav');

  /// Dedicated game-over sting on its own player so BGM stop cannot cancel it.
  Future<void> playGameOver() async {
    await init();
    if (_muted) return;
    try {
      await _ensurePlayersConfigured();
      await _gameOver.stop();
      await _gameOver.play(AssetSource('audio/gameover.wav'));
    } catch (_) {
      // Fallback to hit if the dedicated asset fails.
      try {
        await _playSfx('audio/hit.wav');
      } catch (_) {}
    }
  }

  Future<void> _playSfx(String asset) async {
    await init();
    if (_muted) return;
    try {
      await _ensurePlayersConfigured();
      await _sfx.play(AssetSource(asset));
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _sfx.dispose();
      await _music.dispose();
      await _gameOver.dispose();
    } catch (_) {}
  }
}
