/// Emergency numbers configuration for SOS app.
/// Change these numbers to your real emergency numbers before production.
class EmergencyConfig {
  // ── Testing numbers (change these to real numbers for production) ──
  /// Number to send SMS to when Ambulance SOS is triggered (5 presses)
  static const String ambulanceNumber =
      '03302960285'; // TODO: Replace with real number

  /// Number to send SMS to when Police SOS is triggered (4 presses)
  static const String policeNumber =
      '03302960285'; // TODO: Replace with real number

  // ── Button press configuration ──
  /// Number of rapid volume button presses to trigger Ambulance SOS
  static const int ambulancePressCount = 5;

  /// Number of rapid volume button presses to trigger Police SOS
  static const int policePressCount = 4;

  // / Time window (in seconds) within which all presses must occur
  static const int pressTimeWindowSeconds = 3;
}
