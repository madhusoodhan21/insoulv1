/// Utility class for FSR (Force-Sensitive Resistor) sensor conversions.
class FsrUtils {
  FsrUtils._();

  /// Converts analog ADC counts to kilograms.
  /// 
  /// Assumes a linear relationship where:
  /// - 0 ADC counts = 0 kg
  /// - 1023 ADC counts (10-bit max) = ~100 kg
  /// 
  /// This can be calibrated based on actual sensor characteristics.
  static double analogToKg(int adcValue) {
    // Linear conversion: (ADC value / 1023) * 100 kg
    const int maxAdcValue = 1023;
    const double maxKg = 100.0;
    
    return (adcValue / maxAdcValue) * maxKg;
  }

  /// Converts kilograms back to analog ADC counts.
  static int kgToAnalog(double kg) {
    const int maxAdcValue = 1023;
    const double maxKg = 100.0;
    
    return ((kg / maxKg) * maxAdcValue).round();
  }
}
