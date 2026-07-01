import 'package:flutter/material.dart';
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
  final _latController = TextEditingController(text: '24.7136');
  final _lngController = TextEditingController(text: '46.6753');

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
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
                            value: state.selectedCity,
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
                            value: state.selectedDistrict,
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
                            value: state.selectedNeighborhood,
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
                          // Location coordinates input (replaces Google Maps which is unsupported on web)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5EAF2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        color: Color(0xFF0B3A66), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'إحداثيات موقع العقار',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              color: const Color(0xFF0B3A66),
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _latController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'خط العرض (Latitude)',
                                          hintText: '24.7136',
                                          prefixIcon: Icon(Icons.swap_vert_rounded),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _lngController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'خط الطول (Longitude)',
                                          hintText: '46.6753',
                                          prefixIcon: Icon(Icons.swap_horiz_rounded),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
