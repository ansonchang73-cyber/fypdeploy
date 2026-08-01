// lib/features/medication_management/presentation/widgets/clinic_map_picker.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ===========================================================================
// 🏥 MOCK DATA: NEARBY CLINICS & HOSPITALS (Kuala Lumpur Area)
// ===========================================================================
class ClinicData {
  final String name;
  final String address;
  final LatLng location;

  ClinicData(this.name, this.address, this.location);
}

final List<ClinicData> nearbyClinics = [
  ClinicData('Hospital Kuala Lumpur (HKL)', 'Jalan Pahang', const LatLng(3.1718, 101.7006)),
  ClinicData('Prince Court Medical Centre', 'Jalan Kia Peng', const LatLng(3.1485, 101.7201)),
  ClinicData('Tung Shin Hospital', 'Jalan Pudu', const LatLng(3.1450, 101.7032)),
  ClinicData('Pantai Hospital KL', 'Bangsar', const LatLng(3.1197, 101.6663)),
  ClinicData('Gleneagles Hospital', 'Ampang', const LatLng(3.1600, 101.7381)),
  ClinicData('Sunway Medical Centre', 'Velocity', const LatLng(3.0658, 101.6046)),
];

// ===========================================================================
// 🗺️ FREE FLUTTER_MAP PIN DROPPER (WITH CLICKABLE MEDICAL CROSSES)
// ===========================================================================
/// Extracted from `_showMapPicker` in the old `add_medication_screen.dart`.
/// Previously this mutated `_locationController.text` and called `setState`
/// directly as a closure over the screen's State — now it just reports the
/// chosen location string back through [onLocationSelected], so this
/// widget doesn't need to know anything about the screen that's using it.
void showClinicMapPicker(
  BuildContext context, {
  required ValueChanged<String> onLocationSelected,
}) {
  LatLng currentPin = const LatLng(3.1390, 101.6869); // Centered on Kuala Lumpur
  final MapController mapController = MapController();

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDF7),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: currentPin,
                        initialZoom: 14.0,
                        onTap: (tapPosition, point) {
                          setModalState(() {
                            currentPin = point; // Drops the pin wherever the user clicks
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.fyp.app',
                        ),
                        MarkerLayer(
                          markers: [
                            ...nearbyClinics.map((clinic) {
                              return Marker(
                                point: clinic.location,
                                width: 60,
                                height: 60,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    onLocationSelected("${clinic.name} - ${clinic.address}");
                                    Navigator.pop(context);
                                  },
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(width: 18, height: 5, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(1))),
                                              Container(width: 5, height: 18, decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(1))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),

                            Marker(
                              point: currentPin,
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.location_on, color: Color(0xFF6750A4), size: 45),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    right: 16,
                    top: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: "zoom_in",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            mapController.move(mapController.camera.center, mapController.camera.zoom + 1);
                          },
                          child: const Icon(Icons.add, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: "zoom_out",
                          backgroundColor: Colors.white,
                          onPressed: () {
                            mapController.move(mapController.camera.center, mapController.camera.zoom - 1);
                          },
                          child: const Icon(Icons.remove, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6750A4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      onPressed: () {
                        final matchedClinic = nearbyClinics.where((c) => c.location == currentPin).firstOrNull;

                        if (matchedClinic != null) {
                          onLocationSelected("${matchedClinic.name} - ${matchedClinic.address}");
                        } else {
                          onLocationSelected(
                            "${currentPin.latitude.toStringAsFixed(4)}, ${currentPin.longitude.toStringAsFixed(4)}",
                          );
                        }
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Confirm Pinned Location',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
