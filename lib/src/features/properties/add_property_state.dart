import 'package:flutter/foundation.dart';

class AddPropertyState with ChangeNotifier {
  AddPropertyState() {
    _resetLocationFields();
  }

  final Map<String, List<String>> _districtsByCity = {
    'الرياض': ['النخيل', 'البجيري', 'النسيم'],
    'جدة': ['الحمراء', 'السلامة', 'الكورنيش'],
    'الدمام': ['الملاحة', 'البطحاء', 'الشاطئ'],
  };

  final Map<String, List<String>> _neighborhoodsByDistrict = {
    'النخيل': ['الواحة', 'الزهور'],
    'البجيري': ['البرج', 'الحدائق'],
    'النسيم': ['الصرار', 'الدرعية'],
    'الحمراء': ['الفيصلية', 'النهضة'],
    'السلامة': ['البحيري', 'الروضة'],
    'الكورنيش': ['المنتزه', 'الميناء'],
    'الملاحة': ['القمرة', 'الأمواج'],
    'البطحاء': ['الفلج', 'الريف'],
    'الشاطئ': ['المرجان', 'اللؤلؤ'],
  };

  final List<String> cities = ['الرياض', 'جدة', 'الدمام'];
  List<String> districts = [];
  List<String> neighborhoods = [];

  String? selectedCity;
  String? selectedDistrict;
  String? selectedNeighborhood;

  void onCityChanged(String? city) {
    if (city == null) {
      return;
    }

    selectedCity = city;
    districts = _districtsByCity[city] ?? [];
    selectedDistrict = null;
    neighborhoods = [];
    selectedNeighborhood = null;
    notifyListeners();
  }

  void onDistrictChanged(String? district) {
    if (district == null) {
      return;
    }

    selectedDistrict = district;
    neighborhoods = _neighborhoodsByDistrict[district] ?? [];
    selectedNeighborhood = null;
    notifyListeners();
  }

  void onNeighborhoodChanged(String? neighborhood) {
    selectedNeighborhood = neighborhood;
    notifyListeners();
  }

  void _resetLocationFields() {
    districts = [];
    neighborhoods = [];
    selectedCity = null;
    selectedDistrict = null;
    selectedNeighborhood = null;
  }
}
