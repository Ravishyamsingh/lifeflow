import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/donation_model.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class BloodRequestPage extends StatefulWidget {
  const BloodRequestPage({super.key});

  @override
  State<BloodRequestPage> createState() => _BloodRequestPageState();
}

class _BloodRequestPageState extends State<BloodRequestPage> {
  final DatabaseService _db = DatabaseService();
  final LocationService _loc = LocationService();
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // ── Section 1: Patient Info ──
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  DateTime? _dob;
  String? _relationToPatient;

  // ── Section 2: Medical Info ──
  String? _bloodType;
  final _diseaseController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _doctorController = TextEditingController();
  int _unitsNeeded = 1;
  double? _hospitalLat;
  double? _hospitalLng;
  String? _hospitalAddress;        // full hospital address with pincode
  double? _patientLat;
  double? _patientLng;
  List<PlacePrediction> _hospitalSuggestions = [];
  bool _searchingHospital = false;
  bool _gettingLocation = false;

  // ── Section 3: Request Details ──
  String _urgency = 'urgent';
  DateTime _requiredByDate = DateTime.now().add(const Duration(days: 1));
  final _notesController = TextEditingController();
  bool _isAnonymous = false;

  bool _isLoading = false;
  int _currentPage = 0;

  final List<String> _bloodTypes = [
    'O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'
  ];
  final List<String> _relations = [
    'Self', 'Spouse', 'Parent', 'Child', 'Sibling', 'Relative', 'Friend', 'Other'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _diseaseController.dispose();
    _hospitalController.dispose();
    _doctorController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _validateSection1() {
    if (_fullNameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().length < 7) return false;
    if (_addressController.text.trim().isEmpty) return false;
    if (_dob == null) return false;
    if (_relationToPatient == null) return false;
    return true;
  }

  /// Show a location-error SnackBar with optional "Open Settings" action.
  void _showLocationError(LocationResult result) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.userMessage),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        action: result.canOpenSettings
            ? SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  if (result.status == LocationStatus.serviceDisabled) {
                    _loc.openLocationSettings();
                  } else {
                    _loc.openAppSettings();
                  }
                },
              )
            : null,
      ),
    );
  }

  bool _validateSection2() {
    if (_bloodType == null) return false;
    if (_diseaseController.text.trim().isEmpty) return false;
    if (_hospitalController.text.trim().isEmpty) return false;
    return true;
  }

  void _navigateTo(int page) {
    if (page == 1 && !_validateSection1()) {
      _formKey.currentState?.validate();
      String msg = 'Please fill in all required fields';
      if (_dob == null) msg = 'Please select date of birth';
      if (_relationToPatient == null) msg = 'Please select relation to patient';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      return;
    }
    if (page == 2 && !_validateSection2()) {
      _formKey.currentState?.validate();
      String msg = _bloodType == null
          ? 'Please select a blood type'
          : 'Please fill in all required fields';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      return;
    }
    setState(() => _currentPage = page);
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  Future<void> _submitRequest() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw 'User not found. Please sign in again.';

      final userData = await _db.getUserById(currentUser.uid);
      final fullAddress =
          '${_addressController.text.trim()}, ${_cityController.text.trim()}'
              .trim()
              .replaceAll(RegExp(r',\s*$'), '');

      // Fallback: geocode hospital name if coordinates are missing
      double? hospLat = _hospitalLat;
      double? hospLng = _hospitalLng;
      String? hospAddress = _hospitalAddress;
      if (hospLat == null || hospLng == null) {
        final hospName = _hospitalController.text.trim();
        if (hospName.isNotEmpty) {
          debugPrint('[Submit] Hospital coords missing, geocoding: $hospName');
          final coords = await _loc.geocodeAddress(hospName);
          if (coords != null) {
            hospLat = coords.lat;
            hospLng = coords.lng;
            debugPrint('[Submit] Geocoded hospital: $hospLat, $hospLng');
            // Also try to get full address via reverse geocode
            if (hospAddress == null) {
              try {
                final geo = await _loc.reverseGeocodeDetailed(hospLat, hospLng);
                if (geo != null) {
                  hospAddress = geo.formattedAddress;
                }
              } catch (_) {}
            }
          }
        }
      }

      final donation = DonationModel(
        donationId: DateTime.now().millisecondsSinceEpoch.toString(),
        donorId: '',
        donorName: '',
        donorBloodType: _bloodType!,
        recipientId: currentUser.uid,
        recipientName: _isAnonymous
            ? 'Anonymous'
            : (userData?.name ?? currentUser.displayName ?? 'User'),
        status: 'pending',
        donationDate: _requiredByDate,
        createdAt: DateTime.now(),
        location: hospAddress ?? _hospitalController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        isAnonymous: _isAnonymous,
        patientPhone: _phoneController.text.trim(),
        patientAddress: fullAddress,
        patientDob: _dob,
        patientDisease: _diseaseController.text.trim(),
        hospitalName: _hospitalController.text.trim(),
        doctorName: _doctorController.text.trim().isNotEmpty
            ? _doctorController.text.trim()
            : null,
        unitsNeeded: _unitsNeeded,
        urgency: _urgency,
        relationToPatient: _relationToPatient,
        hospitalLat: hospLat,
        hospitalLng: hospLng,
        hospitalAddress: hospAddress,
        patientLat: _patientLat,
        patientLng: _patientLng,
      );

      await _db.createDonation(donation);
      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: Colors.green.shade50, shape: BoxShape.circle),
                child: Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 44),
              ),
              const SizedBox(height: 20),
              const Text('Request Submitted!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                'Your blood request has been posted. Available donors will be notified and will contact you shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickRequiredDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredByDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      helpText: 'Required By Date',
    );
    if (picked != null) setState(() => _requiredByDate = picked);
  }

  // ─────────  SECTION 1: Patient Info  ─────────
  Widget _buildSection1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.person_outline,
            title: 'Patient Information',
            subtitle: 'Details of the person who needs blood',
          ),
          const SizedBox(height: 24),
          _field(
            controller: _fullNameController,
            label: 'Full Name *',
            hint: "Enter patient's full name",
            icon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Full name is required'
                : null,
          ),
          const SizedBox(height: 16),
          _field(
            controller: _phoneController,
            label: 'Phone Number *',
            hint: 'Enter contact number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.trim().length < 7)
                ? 'Enter a valid phone number'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Date of Birth *'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickDob,
            child: _selectableBox(
              icon: Icons.cake_outlined,
              text: _dob == null
                  ? 'Select date of birth'
                  : '${_dob!.day.toString().padLeft(2, '0')}/'
                      '${_dob!.month.toString().padLeft(2, '0')}/'
                      '${_dob!.year}',
              isEmpty: _dob == null,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _addressController,
            label: 'Address *',
            hint: 'Street / Area / Locality',
            icon: Icons.home_outlined,
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Address is required'
                : null,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: _gettingLocation
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Getting location…',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue.shade600)),
                      ],
                    ),
                  )
                : TextButton.icon(
                    onPressed: () async {
                      setState(() => _gettingLocation = true);
                      final result = await _loc.getPositionDetailed();
                      if (!mounted) return;

                      if (!result.isSuccess) {
                        setState(() => _gettingLocation = false);
                        _showLocationError(result);
                        return;
                      }

                      final pos = result.position!;
                      // Store patient coordinates
                      _patientLat = pos.latitude;
                      _patientLng = pos.longitude;

                      // Use detailed reverse geocode for full address with components
                      final geo = await _loc.reverseGeocodeDetailed(
                          pos.latitude, pos.longitude);
                      if (!mounted) return;

                      setState(() {
                        _gettingLocation = false;
                        if (geo != null) {
                          // Set the full formatted address
                          _addressController.text = geo.formattedAddress;
                          // Auto-fill city if empty
                          if (_cityController.text.trim().isEmpty &&
                              geo.city != null) {
                            _cityController.text = geo.city!;
                          }
                        } else {
                          // Reverse geocode failed — use coordinates as fallback
                          _addressController.text =
                              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
                        }
                      });

                      if (geo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Got GPS coordinates but could not resolve address. '
                                'Check internet or Google API key.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.my_location,
                        size: 16, color: Colors.blue.shade600),
                    label: Text('Use Current Location',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade600)),
                  ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _cityController,
            label: 'City / District',
            hint: 'City or district name',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 16),
          _label('Relation to Patient *'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _relations.map((r) {
              final sel = _relationToPatient == r;
              return GestureDetector(
                onTap: () => setState(() => _relationToPatient = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? Colors.red.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? Colors.red.shade600 : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(r,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : Colors.black87,
                      )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────  SECTION 2: Medical Info  ─────────
  Widget _buildSection2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.medical_information_outlined,
            title: 'Medical Details',
            subtitle: 'Provide the medical information for the request',
          ),
          const SizedBox(height: 24),
          _label('Required Blood Type *'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _bloodTypes.map((type) {
              final sel = _bloodType == type;
              return GestureDetector(
                onTap: () => setState(() => _bloodType = type),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 64,
                  height: 52,
                  decoration: BoxDecoration(
                    color: sel ? Colors.red.shade600 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? Colors.red.shade600 : Colors.grey.shade300,
                      width: sel ? 2.5 : 1.5,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(type,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: sel ? Colors.white : Colors.black87,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('Units of Blood Needed *'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    color: Colors.red.shade600, size: 22),
                const SizedBox(width: 12),
                const Text('Units Required',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: _unitsNeeded > 1
                      ? () => setState(() => _unitsNeeded--)
                      : null,
                  icon: Icon(Icons.remove_circle_outline,
                      color: _unitsNeeded > 1
                          ? Colors.red.shade600
                          : Colors.grey),
                ),
                Text('$_unitsNeeded',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: _unitsNeeded < 10
                      ? () => setState(() => _unitsNeeded++)
                      : null,
                  icon: Icon(Icons.add_circle_outline,
                      color: _unitsNeeded < 10
                          ? Colors.red.shade600
                          : Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _diseaseController,
            label: 'Disease / Medical Condition *',
            hint: 'e.g. Thalassemia, Accident, Surgery, Cancer...',
            icon: Icons.sick_outlined,
            maxLines: 2,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Please enter the medical condition'
                : null,
          ),
          const SizedBox(height: 16),
          _label('Hospital / Clinic Name *'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _hospitalController,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Hospital name is required'
                : null,
            onChanged: (val) async {
              // User is typing manually — clear previously captured coords
              // (they'll be re-resolved on selection or on submit)
              _hospitalLat = null;
              _hospitalLng = null;
              _hospitalAddress = null;

              if (val.trim().length < 3) {
                setState(() => _hospitalSuggestions = []);
                return;
              }
              setState(() => _searchingHospital = true);
              // Search for hospitals/clinics — no type restriction so all
              // results (establishments, addresses, areas) appear
              final results = await _loc.searchPlaces(val.trim(),
                  types: 'establishment');
              // If no establishment results, try without type restriction
              List<PlacePrediction> finalResults = results;
              if (results.isEmpty) {
                finalResults = await _loc.searchPlaces(val.trim());
              }
              if (mounted) {
                setState(() {
                  _hospitalSuggestions = finalResults;
                  _searchingHospital = false;
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Search hospital or clinic',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.local_hospital_outlined,
                  color: Colors.grey.shade600, size: 20),
              suffixIcon: _searchingHospital
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _hospitalLat != null
                      ? Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 20)
                      : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      BorderSide(color: Colors.red.shade500, width: 2)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.red.shade400)),
            ),
          ),
          if (_hospitalSuggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _hospitalSuggestions.length > 5
                    ? 5
                    : _hospitalSuggestions.length,
                separatorBuilder: (_, a) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final place = _hospitalSuggestions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.location_on,
                        color: Colors.red.shade400, size: 20),
                    title: Text(place.mainText,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(place.description,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      _hospitalController.text = place.mainText;
                      setState(() {
                        _hospitalSuggestions = [];
                      });
                      // Nominatim search already returns lat/lng
                      if (place.lat != null && place.lng != null) {
                        if (mounted) {
                          setState(() {
                            _hospitalLat = place.lat;
                            _hospitalLng = place.lng;
                            _hospitalAddress = place.description;
                          });
                        }
                      } else {
                        // Fallback: geocode the description text
                        setState(() => _searchingHospital = true);
                        final coords =
                            await _loc.geocodeAddress(place.description);
                        if (coords != null && mounted) {
                          setState(() {
                            _hospitalLat = coords.lat;
                            _hospitalLng = coords.lng;
                            _hospitalAddress = place.description;
                            _searchingHospital = false;
                          });
                        } else if (mounted) {
                          setState(() => _searchingHospital = false);
                        }
                      }
                    },
                  );
                },
              ),
            ),
          if (_hospitalLat != null && _hospitalLng != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _hospitalAddress ?? _hospitalController.text,
                          style: TextStyle(
                              fontSize: 11, color: Colors.green.shade700,
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, top: 2),
                    child: Text(
                      '📍 ${_hospitalLat!.toStringAsFixed(4)}, ${_hospitalLng!.toStringAsFixed(4)}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _field(
            controller: _doctorController,
            label: "Doctor's Name",
            hint: 'Attending doctor (optional)',
            icon: Icons.medical_services_outlined,
          ),
        ],
      ),
    );
  }

  // ─────────  SECTION 3: Request Details  ─────────
  Widget _buildSection3() {
    final urgencyOptions = [
      (
        'critical',
        'Critical / Emergency',
        'Need blood within hours. Life at risk',
        Colors.red.shade700,
        Icons.warning_amber_rounded
      ),
      (
        'urgent',
        'Urgent',
        'Need blood within 1–2 days',
        Colors.orange.shade700,
        Icons.access_time_filled
      ),
      (
        'normal',
        'Normal / Planned',
        'Operation or transfusion planned in advance',
        Colors.green.shade700,
        Icons.event_available
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.assignment_outlined,
            title: 'Request Details',
            subtitle: 'Urgency, timeline and extra information',
          ),
          const SizedBox(height: 24),
          _label('Urgency Level *'),
          const SizedBox(height: 12),
          ...urgencyOptions.map((opt) {
            final sel = _urgency == opt.$1;
            return GestureDetector(
              onTap: () => setState(() => _urgency = opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? opt.$4.withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? opt.$4 : Colors.grey.shade300,
                    width: sel ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: sel
                            ? opt.$4.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(opt.$5,
                          color: sel ? opt.$4 : Colors.grey, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.$2,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sel ? opt.$4 : Colors.black87,
                              )),
                          const SizedBox(height: 3),
                          Text(opt.$3,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (sel) Icon(Icons.check_circle, color: opt.$4, size: 20),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _label('Blood Required By *'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickRequiredDate,
            child: _selectableBox(
              icon: Icons.calendar_today,
              text:
                  '${_requiredByDate.day.toString().padLeft(2, '0')}/'
                  '${_requiredByDate.month.toString().padLeft(2, '0')}/'
                  '${_requiredByDate.year}',
              isEmpty: false,
            ),
          ),
          const SizedBox(height: 16),
          _field(
            controller: _notesController,
            label: 'Additional Notes',
            hint: 'Any other information for the donor (optional)...',
            icon: Icons.note_outlined,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SwitchListTile(
              title: const Text('Post Anonymously',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Hide your name from donors'),
              value: _isAnonymous,
              activeTrackColor: Colors.red.shade600,
              onChanged: (v) => setState(() => _isAnonymous = v),
            ),
          ),
          const SizedBox(height: 28),
          _buildSummaryCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.summarize_outlined, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('Request Summary',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          ...[
            ('Patient', _fullNameController.text.trim()),
            ('Phone', _phoneController.text.trim()),
            ('Blood Type', _bloodType ?? '-'),
            ('Units', '$_unitsNeeded unit(s)'),
            ('Condition', _diseaseController.text.trim()),
            ('Hospital', _hospitalController.text.trim()),
            ('Urgency', _urgency.toUpperCase()),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text('${item.$1}:',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Text(
                      item.$2.isNotEmpty ? item.$2 : '-',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────  SHARED WIDGETS  ─────────
  Widget _sectionHeader(
      {required IconData icon,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: Colors.red.shade500, width: 2)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.red.shade400)),
          ),
        ),
      ],
    );
  }

  Widget _selectableBox(
      {required IconData icon,
      required String text,
      required bool isEmpty}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600, size: 20),
          const SizedBox(width: 12),
          Text(text,
              style: TextStyle(
                fontSize: 15,
                color: isEmpty ? Colors.grey.shade400 : Colors.black87,
              )),
          const Spacer(),
          Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  // ─────────  STEP INDICATOR  ─────────
  Widget _buildStepIndicator() {
    final steps = ['Patient Info', 'Medical', 'Details'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: List.generate(steps.length, (i) {
          final done = i < _currentPage;
          final active = i == _currentPage;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: done
                                  ? Colors.green.shade600
                                  : active
                                      ? Colors.red.shade600
                                      : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: done
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : Text('${i + 1}',
                                      style: TextStyle(
                                        color: active
                                            ? Colors.white
                                            : Colors.grey.shade500,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      )),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(steps[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: active
                                ? Colors.red.shade600
                                : done
                                    ? Colors.green.shade600
                                    : Colors.grey,
                          )),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      color: i < _currentPage
                          ? Colors.green.shade400
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ─────────  MAIN BUILD  ─────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigateTo(_currentPage - 1);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              if (_currentPage > 0) {
                _navigateTo(_currentPage - 1);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Blood Request Form',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: _buildStepIndicator(),
          ),
        ),
        body: Form(
          key: _formKey,
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildSection1(),
            _buildSection2(),
            _buildSection3(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          color: Colors.white,
          child: Row(
            children: [
              if (_currentPage > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _navigateTo(_currentPage - 1),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Back',
                        style: TextStyle(color: Colors.black87)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_currentPage < 2) {
                            _navigateTo(_currentPage + 1);
                          } else {
                            _submitRequest();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPage == 2
                        ? Colors.green.shade600
                        : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == 2 ? 'Submit Request' : 'Next',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentPage == 2
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
