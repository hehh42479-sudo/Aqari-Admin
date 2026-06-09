import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'add_property_state.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  LatLng _selectedLocation = const LatLng(24.7136, 46.6753);
  Set<Marker> _markers = {
    const Marker(
      markerId: MarkerId('property-pin'),
      position: LatLng(24.7136, 46.6753),
    )
  };

  void _updateLocation(LatLng location) {
    setState(() {
      _selectedLocation = location;
      _markers = {
        Marker(
          markerId: const MarkerId('property-pin'),
          position: location,
        ),
      };
    });
  }

  void _saveProperty() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ بيانات العقار مؤقتاً.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AddPropertyState>(
      create: (_) => AddPropertyState(),
      child: Consumer<AddPropertyState>(
        builder: (context, state, child) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'إضافة عقار جديد',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان العقار',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال عنوان العقار.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'السعر',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'يرجى إدخال السعر.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'وصف العقار',
                            ),
                          ),
                          const SizedBox(height: 18),
                          DropdownButtonFormField<String>(
                            initialValue: state.selectedCity,
                            decoration: const InputDecoration(
                              labelText: 'المدينة',
                            ),
                            items: state.cities
                                .map(
                                  (city) => DropdownMenuItem(
                                    value: city,
                                    child: Text(city),
                                  ),
                                )
                                .toList(),
                            onChanged: state.onCityChanged,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: state.selectedDistrict,
                            decoration: const InputDecoration(
                              labelText: 'الحي',
                            ),
                            items: state.districts
                                .map(
                                  (district) => DropdownMenuItem(
                                    value: district,
                                    child: Text(district),
                                  ),
                                )
                                .toList(),
                            onChanged: state.onDistrictChanged,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: state.selectedNeighborhood,
                            decoration: const InputDecoration(
                              labelText: 'المنطقة',
                            ),
                            items: state.neighborhoods
                                .map(
                                  (neighborhood) => DropdownMenuItem(
                                    value: neighborhood,
                                    child: Text(neighborhood),
                                  ),
                                )
                                .toList(),
                            onChanged: state.onNeighborhoodChanged,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'اختر موقع العقار على الخريطة بالضغط عليها',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 300,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: GoogleMap(
                                initialCameraPosition: CameraPosition(
                                  target: _selectedLocation,
                                  zoom: 12,
                                ),
                                markers: _markers,
                                onTap: _updateLocation,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                mapType: MapType.normal,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الإحداثيات: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: _saveProperty,
                              child: const Text('حفظ العقار'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
