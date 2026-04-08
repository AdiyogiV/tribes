/// Utility class for converting Gregorian dates to various calendar systems.
/// 
/// Supports:
/// - Jain (Vira Nirvana Samvat) - Lunar calendar, same structure as Vedic
/// - Buddhist Era - Lunar calendar, same structure as Vedic
/// - Sikh (Nanakshahi) - Solar calendar with fixed months
class WorldCalendarUtils {
  // ============================================================================
  // JAIN CALENDAR - Vira Nirvana Samvat
  // ============================================================================
  
  /// Convert Gregorian year to Vira Nirvana Samvat year.
  /// Epoch: 527 BCE (Mahavira's Nirvana)
  /// VNS year = Gregorian year + 527
  static int getViraSamvatYear(int gregorianYear) => gregorianYear + 527;
  
  /// Convert Vikram Samvat year to Vira Nirvana Samvat year.
  /// VNS = Vikram + 470
  static int vikramToViraSamvat(int vikramYear) => vikramYear + 470;

  // ============================================================================
  // BUDDHIST CALENDAR - Buddhist Era (BE)
  // ============================================================================
  
  /// Convert Gregorian year to Buddhist Era year.
  /// Epoch: 543 BCE (Buddha's Parinirvana)
  /// BE year = Gregorian year + 543
  static int getBuddhistYear(int gregorianYear) => gregorianYear + 543;
  
  /// Convert Vikram Samvat year to Buddhist Era year.
  /// BE = Vikram + 486
  static int vikramToBuddhistEra(int vikramYear) => vikramYear + 486;

  // ============================================================================
  // SIKH CALENDAR - Nanakshahi
  // ============================================================================
  
  /// Convert Gregorian year to Nanakshahi year.
  /// Epoch: 1469 CE (Guru Nanak's birth)
  /// NS year = Gregorian year - 1469
  static int getNanakshahiYear(int gregorianYear) => gregorianYear - 1469;
  
  /// Nanakshahi month names (solar calendar with fixed months)
  static const List<String> nanakshahiMonths = [
    'Chet',      // 1 - March 14
    'Vaisakh',   // 2 - April 14
    'Jeth',      // 3 - May 15
    'Harh',      // 4 - June 15
    'Sawan',     // 5 - July 16
    'Bhadon',    // 6 - August 16
    'Assu',      // 7 - September 15
    'Kattak',    // 8 - October 15
    'Maghar',    // 9 - November 14
    'Poh',       // 10 - December 14
    'Magh',      // 11 - January 13
    'Phagun',    // 12 - February 12
  ];
  
  /// Nanakshahi month start dates (day of Gregorian month when NS month starts)
  /// Format: [monthIndex, startDay] where monthIndex is 1-12 (Jan-Dec)
  static const List<List<int>> _nanakshahiMonthStarts = [
    [3, 14],   // Chet starts March 14
    [4, 14],   // Vaisakh starts April 14
    [5, 15],   // Jeth starts May 15
    [6, 15],   // Harh starts June 15
    [7, 16],   // Sawan starts July 16
    [8, 16],   // Bhadon starts August 16
    [9, 15],   // Assu starts September 15
    [10, 15],  // Kattak starts October 15
    [11, 14],  // Maghar starts November 14
    [12, 14],  // Poh starts December 14
    [1, 13],   // Magh starts January 13
    [2, 12],   // Phagun starts February 12
  ];
  
  /// Get Nanakshahi date from Gregorian date.
  /// Returns a map with 'year', 'month', 'monthName', 'day'.
  static Map<String, dynamic> getFullNanakshahiDate(DateTime gregorianDate) {
    final gYear = gregorianDate.year;
    final gMonth = gregorianDate.month;
    final gDay = gregorianDate.day;
    
    // Find which Nanakshahi month we're in
    int nsMonthIndex = -1;
    int nsDay = 0;
    int nsYear = gYear - 1469;
    
    for (int i = 0; i < _nanakshahiMonthStarts.length; i++) {
      final startMonth = _nanakshahiMonthStarts[i][0];
      final startDay = _nanakshahiMonthStarts[i][1];
      
      // Get the next month's start
      final nextI = (i + 1) % _nanakshahiMonthStarts.length;
      final nextStartMonth = _nanakshahiMonthStarts[nextI][0];
      final nextStartDay = _nanakshahiMonthStarts[nextI][1];
      
      // Check if current Gregorian date falls in this NS month
      bool inThisMonth = false;
      
      if (startMonth == gMonth && gDay >= startDay) {
        // Same month, after start day
        inThisMonth = true;
        nsDay = gDay - startDay + 1;
      } else if (startMonth < nextStartMonth) {
        // Normal case: start month < next start month
        if (gMonth == startMonth && gDay >= startDay) {
          inThisMonth = true;
          nsDay = gDay - startDay + 1;
        } else if (gMonth > startMonth && gMonth < nextStartMonth) {
          inThisMonth = true;
          // Calculate days from start
          final daysInStartMonth = _daysInMonth(startMonth, gYear);
          nsDay = (daysInStartMonth - startDay + 1) + gDay;
          if (gMonth > startMonth + 1) {
            for (int m = startMonth + 1; m < gMonth; m++) {
              nsDay += _daysInMonth(m, gYear);
            }
          }
        } else if (gMonth == nextStartMonth && gDay < nextStartDay) {
          inThisMonth = true;
          final daysInStartMonth = _daysInMonth(startMonth, gYear);
          nsDay = (daysInStartMonth - startDay + 1);
          for (int m = startMonth + 1; m < gMonth; m++) {
            nsDay += _daysInMonth(m, gYear);
          }
          nsDay += gDay;
        }
      } else {
        // Year boundary case (e.g., Poh: Dec 14 to Jan 12)
        if (gMonth == startMonth && gDay >= startDay) {
          inThisMonth = true;
          nsDay = gDay - startDay + 1;
        } else if (gMonth == 12 && startMonth == 12 && gDay >= startDay) {
          inThisMonth = true;
          nsDay = gDay - startDay + 1;
        } else if (gMonth < nextStartMonth && startMonth == 12) {
          // In January before next month starts
          if (gMonth == 1 && gDay < nextStartDay) {
            inThisMonth = true;
            nsDay = (31 - startDay + 1) + gDay; // Days left in Dec + Jan days
          }
        }
      }
      
      if (inThisMonth) {
        nsMonthIndex = i;
        break;
      }
    }
    
    // Adjust year for months that span year boundary
    // Nanakshahi year starts on Chet 1 (March 14)
    if (gMonth < 3 || (gMonth == 3 && gDay < 14)) {
      nsYear = gYear - 1469 - 1;
    }
    
    // Fallback if no month found (shouldn't happen)
    if (nsMonthIndex == -1) {
      nsMonthIndex = 0;
      nsDay = 1;
    }
    
    return {
      'year': nsYear,
      'month': nsMonthIndex + 1,
      'monthName': nanakshahiMonths[nsMonthIndex],
      'day': nsDay,
      'weekday': gregorianDate.weekday, // 1=Monday, 7=Sunday
    };
  }
  
  /// Helper to get days in a Gregorian month
  static int _daysInMonth(int month, int year) {
    const daysInMonths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && _isLeapYear(year)) {
      return 29;
    }
    return daysInMonths[month - 1];
  }
  
  /// Check if a year is a leap year
  static bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }
}
