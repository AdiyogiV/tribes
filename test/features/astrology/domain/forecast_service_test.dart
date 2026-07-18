import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthKey zero-pads month document identifiers', () {
    expect(ForecastService.monthKey(DateTime(2026, 1, 31)), '2026-01');
    expect(ForecastService.monthKey(DateTime(2026, 12, 1)), '2026-12');
  });
}
