import 'package:flutter/material.dart';

IconData iconForCategory(String icon) {
  switch (icon) {
    case 'badge':
      return Icons.badge_outlined;
    case 'school':
      return Icons.school_outlined;
    case 'account_balance':
      return Icons.account_balance_outlined;
    case 'medical_services':
      return Icons.medical_services_outlined;
    case 'directions_car':
      return Icons.directions_car_outlined;
    case 'flight':
      return Icons.flight_outlined;
    default:
      return Icons.folder_outlined;
  }
}
