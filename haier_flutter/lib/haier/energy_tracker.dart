import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 电量采样点。
class EnergySample {
  EnergySample(this.time, this.energyKwh);
  final DateTime time;
  final double energyKwh;

  Map<String, dynamic> toJson() => {
    't': time.millisecondsSinceEpoch,
    'e': energyKwh,
  };
  static EnergySample fromJson(Map<String, dynamic> j) => EnergySample(
    DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    (j['e'] as num).toDouble(),
  );
}

/// 记录累计电量采样，计算今日 / 近7天 / 自追踪起的用电量。
///
/// 设备的 energySaved 是「累计总电量」，日用电 = 今日末 - 今日初（跨零点用最近的采样做基线）。
class EnergyTracker {
  EnergyTracker._();
  static final EnergyTracker instance = EnergyTracker._();

  static const _maxSamples = 5000;
  final List<EnergySample> _samples = [];
  Future<void> _writes = Future.value();

  List<EnergySample> get samples => List.unmodifiable(_samples);

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/haier_energy.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      _samples
        ..clear()
        ..addAll(
          list.map((e) => EnergySample.fromJson(e as Map<String, dynamic>)),
        );
      _samples.sort((a, b) => a.time.compareTo(b.time));
    } catch (_) {}
  }

  Future<void> _save() {
    final json = jsonEncode(_samples.map((e) => e.toJson()).toList());
    return _writes = _writes.then((_) async {
      try {
        final file = await _file();
        final pending = File('${file.path}.tmp');
        await pending.writeAsString(json, flush: true);
        await pending.rename(file.path);
      } catch (_) {}
    });
  }

  Future<void> flush() => _writes;

  /// 记录一次累计电量读数（同一时刻重复值会覆盖）。
  Future<void> record(double energyKwh) => recordAt(DateTime.now(), energyKwh);

  /// 在指定时刻记录读数（供历史/演示数据）。
  Future<void> recordAt(DateTime time, double energyKwh) async {
    if (_samples.isNotEmpty) {
      final last = _samples.last;
      if (time.difference(last.time).inSeconds < 20 &&
          (last.energyKwh - energyKwh).abs() < 0.001) {
        return;
      }
    }
    _samples.add(EnergySample(time, energyKwh));
    _samples.sort((a, b) => a.time.compareTo(b.time));
    if (_samples.length > _maxSamples) {
      _samples.removeRange(0, _samples.length - _maxSamples);
    }
    await _save();
  }

  /// 今日起点的累计电量：取今日 00:00 前最近一次采样，否则取今日最早采样。
  double? _baselineToday(DateTime now) {
    final midnight = DateTime(now.year, now.month, now.day);
    EnergySample? beforeMidnight;
    EnergySample? firstToday;
    for (final s in _samples) {
      if (s.time.isBefore(midnight)) {
        beforeMidnight = s;
      } else if (s.time.isBefore(now)) {
        firstToday ??= s;
      }
    }
    if (beforeMidnight != null) return beforeMidnight.energyKwh;
    if (firstToday != null) return firstToday.energyKwh;
    return null;
  }

  /// 今日用电量 (kWh)。当前累计值需传入。
  double? todayUsage(double currentEnergyKwh) {
    final base = _baselineToday(DateTime.now());
    if (base == null) return null;
    final d = currentEnergyKwh - base;
    return d < 0 ? 0 : d;
  }

  /// 自追踪起的总用电 (kWh)。
  double? totalUsage(double currentEnergyKwh) {
    if (_samples.isEmpty) return null;
    final d = currentEnergyKwh - _samples.first.energyKwh;
    return d < 0 ? 0 : d;
  }

  /// 近 n 天每日用电（含今日），返回 [{date, kwh}]，按日期升序。
  List<Map<String, dynamic>> dailyUsage(
    double currentEnergyKwh, {
    int days = 7,
  }) {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final nextDay = day.add(const Duration(days: 1));
      // 当日末值：含 currentEnergyKwh（今天）或当日最后一次采样
      double? endVal;
      if (i == 0) {
        endVal = currentEnergyKwh;
      } else {
        for (final s in _samples) {
          if (s.time.isBefore(nextDay)) endVal = s.energyKwh;
        }
      }
      // 当日初值：前一日最后一次采样，否则当日最早
      double? startVal;
      EnergySample? beforeDay;
      EnergySample? firstOfDay;
      for (final s in _samples) {
        if (s.time.isBefore(day)) {
          beforeDay = s;
        } else if (s.time.isBefore(nextDay)) {
          firstOfDay ??= s;
        }
      }
      startVal = beforeDay?.energyKwh ?? firstOfDay?.energyKwh;
      double? usage;
      if (endVal != null && startVal != null) {
        usage = endVal - startVal;
        if (usage < 0) usage = 0;
      }
      result.add({'date': '${day.month}/${day.day}', 'kwh': usage});
    }
    return result;
  }
}
