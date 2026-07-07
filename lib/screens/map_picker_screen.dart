import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class MapPickerScreen extends StatefulWidget {
  final StorageService storageService;

  const MapPickerScreen({super.key, required this.storageService});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();
  bool _isLoading = false;
  
  // Search related
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.storageService.customLat;
    final lon = widget.storageService.customLon;
    if (lat != 0.0 || lon != 0.0) {
      _selectedLocation = LatLng(lat, lon);
    } else {
      _selectedLocation = const LatLng(23.8812456, 71.1809174); // Default to Charanka, Patan (385350)
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&lat=${_selectedLocation.latitude}&lon=${_selectedLocation.longitude}&format=json&limit=15'),
        headers: {'User-Agent': 'com.netforge.app'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _searchResults = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Search API Error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _onSave() async {
    setState(() => _isLoading = true);

    double elevation = 42.0; // Fallback
    try {
      final response = await http.get(Uri.parse(
          'https://api.open-elevation.com/api/v1/lookup?locations=${_selectedLocation.latitude},${_selectedLocation.longitude}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          elevation = (data['results'][0]['elevation'] as num).toDouble();
        }
      }
    } catch (e) {
      debugPrint('Elevation API Error: $e');
    }

    widget.storageService.setCustomLat(_selectedLocation.latitude);
    widget.storageService.setCustomLon(_selectedLocation.longitude);
    widget.storageService.setCustomElev(elevation);
    
    if (mounted) {
      Navigator.pop(context, _selectedLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PICK LOCATION'),
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _onSave,
                )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 17.0, // Zoomed in default
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.netforge.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Floating Search Bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF1A2535),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search nearby (e.g., mandir, shop)',
                  hintStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF00FFD1)),
                  suffixIcon: _isSearching 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFD1))),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                          });
                        },
                      ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: _searchPlaces,
              ),
            ),
          ),

          // Sliding Bottom Panel for Results
          if (_searchResults.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.4,
              minChildSize: 0.2,
              maxChildSize: 0.7,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1520),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2))
                    ],
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final place = _searchResults[index];
                            final lat = double.parse(place['lat']);
                            final lon = double.parse(place['lon']);
                            return ListTile(
                              leading: const Icon(Icons.place, color: Color(0xFF00B4D8)),
                              title: Text(place['name'] ?? place['display_name'] ?? 'Unknown', style: const TextStyle(color: Colors.white)),
                              subtitle: Text(place['display_name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              onTap: () {
                                final point = LatLng(lat, lon);
                                setState(() {
                                  _selectedLocation = point;
                                });
                                _mapController.move(point, 18.0);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
