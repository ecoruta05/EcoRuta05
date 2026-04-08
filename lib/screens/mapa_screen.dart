import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/punto_compra.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();
  final LatLng _villavicencio = const LatLng(4.1420, -73.6266);

  LatLng? _miUbicacion;
  PuntoCompra? _puntoSeleccionado;
  List<PuntoCompra> _puntosCompra = const [];

  bool _cargandoUbicacion = true;
  bool _cargandoPuntos = true;
  String? _mensajeUbicacion;
  String? _mensajePuntos;

  @override
  void initState() {
    super.initState();
    _cargarPantalla();
  }

  Future<void> _cargarPantalla() async {
    await Future.wait([
      _obtenerUbicacion(),
      _cargarPuntosCompra(),
    ]);
  }

  Future<void> _obtenerUbicacion() async {
    if (mounted) {
      setState(() {
        _cargandoUbicacion = true;
        _mensajeUbicacion = null;
      });
    }

    try {
      final servicioActivo = await Geolocator.isLocationServiceEnabled();
      if (!servicioActivo) {
        setState(() {
          _cargandoUbicacion = false;
          _mensajeUbicacion = 'Activa el GPS para ver tu ubicacion actual.';
        });
        return;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }

      if (permiso == LocationPermission.denied) {
        setState(() {
          _cargandoUbicacion = false;
          _mensajeUbicacion = 'Permiso de ubicacion denegado.';
        });
        return;
      }

      if (permiso == LocationPermission.deniedForever) {
        setState(() {
          _cargandoUbicacion = false;
          _mensajeUbicacion =
              'Permiso bloqueado. Habilitalo desde ajustes del telefono.';
        });
        return;
      }

      final posicion = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      final ubicacion = LatLng(posicion.latitude, posicion.longitude);
      setState(() {
        _miUbicacion = ubicacion;
        _cargandoUbicacion = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoUbicacion = false;
        _mensajeUbicacion = 'No fue posible obtener tu ubicacion en este momento.';
      });
    }
  }

  Future<void> _cargarPuntosCompra() async {
    if (mounted) {
      setState(() {
        _cargandoPuntos = true;
        _mensajePuntos = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.authBaseUrl}/api/puntos-compra?ciudad=Villavicencio'),
      );

      if (response.statusCode != 200) {
        throw Exception('El servidor respondio con ${response.statusCode}');
      }

      final lista = jsonDecode(response.body) as List<dynamic>;
      final puntos = lista
          .map((item) => PuntoCompra.fromJson(item as Map<String, dynamic>))
          .where(
            (punto) =>
                punto.ubicacion.latitude != 0 || punto.ubicacion.longitude != 0,
          )
          .toList();

      if (!mounted) return;

      setState(() {
        _puntosCompra = puntos;
        _puntoSeleccionado = puntos.isNotEmpty ? puntos.first : null;
        _cargandoPuntos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoPuntos = false;
        _mensajePuntos =
            'No se pudieron cargar los puntos de compra desde el backend.';
      });
    }
  }

  void _seleccionarPunto(PuntoCompra punto) {
    setState(() => _puntoSeleccionado = punto);
    _mapController.move(punto.ubicacion, 15);
  }

  void _irAVillavicencio() {
    _mapController.move(_villavicencio, 13);
  }

  void _irAMiUbicacion() {
    final ubicacion = _miUbicacion;
    if (ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todavia no tenemos tu ubicacion disponible.'),
        ),
      );
      return;
    }

    _mapController.move(ubicacion, 15);
  }

  void _mostrarTodosLosPuntos() {
    if (_puntosCompra.isEmpty && _miUbicacion == null) {
      return;
    }

    final bounds = LatLngBounds.fromPoints([
      ..._puntosCompra.map((p) => p.ubicacion),
      if (_miUbicacion != null) _miUbicacion!,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(56),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puntos de compra en Villavicencio'),
        backgroundColor: const Color(0xFF1A3A2A),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(4.1420, -73.6266),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ecoruta_temp',
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildEstadoUbicacion(),
                if (_buildEstadoUbicacion() is! SizedBox) const SizedBox(height: 12),
                _buildEstadoPuntos(),
                const SizedBox(height: 12),
                _buildResumenPuntos(),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildTarjetaPunto(),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'refrescar',
            backgroundColor: const Color(0xFF6D4C41),
            onPressed: _cargarPantalla,
            child: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'todos',
            backgroundColor: const Color(0xFF8E6E53),
            onPressed: _mostrarTodosLosPuntos,
            child: const Icon(Icons.filter_center_focus_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'villavo',
            backgroundColor: const Color(0xFF2E7D32),
            onPressed: _irAVillavicencio,
            child: const Icon(Icons.location_city),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'miposicion',
            backgroundColor: const Color(0xFF1565C0),
            onPressed: _irAMiUbicacion,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers() {
    return [
      ..._puntosCompra.map((punto) {
        final seleccionado = _puntoSeleccionado?.id == punto.id;
        return Marker(
          point: punto.ubicacion,
          width: 92,
          height: 92,
          child: GestureDetector(
            onTap: () => _seleccionarPunto(punto),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorPorMaterial(punto).withOpacity(
                  seleccionado ? 0.96 : 0.85,
                ),
                border: Border.all(
                  color: Colors.white,
                  width: seleccionado ? 3 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _colorPorMaterial(punto).withOpacity(0.35),
                    blurRadius: seleccionado ? 18 : 10,
                    spreadRadius: seleccionado ? 2 : 0,
                  ),
                ],
              ),
              child: Icon(
                _iconoPorMaterial(punto),
                color: Colors.white,
                size: seleccionado ? 34 : 28,
              ),
            ),
          ),
        );
      }),
      if (_miUbicacion != null)
        Marker(
          point: _miUbicacion!,
          width: 88,
          height: 88,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1565C0).withOpacity(0.92),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.35),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
    ];
  }

  Widget _buildEstadoUbicacion() {
    if (_cargandoUbicacion) {
      return const _InfoCard(
        color: Color(0xDD1A3A2A),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Obteniendo ubicacion...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_mensajeUbicacion != null) {
      return _InfoCard(
        color: const Color(0xDDAA2E25),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _mensajeUbicacion!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: _obtenerUbicacion,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildEstadoPuntos() {
    if (_cargandoPuntos) {
      return const _InfoCard(
        color: Color(0xCC163525),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cargando puntos de compra...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_mensajePuntos != null) {
      return _InfoCard(
        color: const Color(0xDDAA2E25),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _mensajePuntos!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            IconButton(
              onPressed: _cargarPuntosCompra,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildResumenPuntos() {
    return _InfoCard(
      color: const Color(0xCC163525),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Color(0xFF81C784)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_puntosCompra.length} puntos de compra cargados para Villavicencio',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPunto() {
    final punto = _puntoSeleccionado;
    if (punto == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xEE10281D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'Selecciona un punto en el mapa para ver que materiales compra y su informacion detallada.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xEE10281D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _colorPorMaterial(punto).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconoPorMaterial(punto), color: _colorPorMaterial(punto)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      punto.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      punto.direccion,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetalle(icono: Icons.location_on_outlined, texto: punto.barrio),
          if (punto.referencia.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDetalle(icono: Icons.place_outlined, texto: punto.referencia),
          ],
          const SizedBox(height: 10),
          _buildDetalle(icono: Icons.schedule_rounded, texto: punto.horario),
          if (punto.telefono.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDetalle(icono: Icons.phone_outlined, texto: punto.telefono),
          ],
          if (punto.descripcion.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildDetalle(
              icono: Icons.info_outline_rounded,
              texto: punto.descripcion,
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Materiales que compran',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: punto.materialesCompra
                .map(
                  (material) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _colorPorMaterial(punto).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _colorPorMaterial(punto).withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      material,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle({required IconData icono, required String texto}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: Colors.white70, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
        ),
      ],
    );
  }

  Color _colorPorMaterial(PuntoCompra punto) {
    final materiales = punto.materialesCompra.join(' ').toLowerCase();

    if (materiales.contains('metal') ||
        materiales.contains('cobre') ||
        materiales.contains('aluminio') ||
        materiales.contains('hierro')) {
      return const Color(0xFFFFB300);
    }

    if (materiales.contains('vidrio')) {
      return const Color(0xFF26A69A);
    }

    if (materiales.contains('carton') || materiales.contains('papel')) {
      return const Color(0xFF8D6E63);
    }

    return const Color(0xFF43A047);
  }

  IconData _iconoPorMaterial(PuntoCompra punto) {
    final materiales = punto.materialesCompra.join(' ').toLowerCase();

    if (materiales.contains('metal') ||
        materiales.contains('cobre') ||
        materiales.contains('aluminio') ||
        materiales.contains('hierro')) {
      return Icons.precision_manufacturing_outlined;
    }

    if (materiales.contains('vidrio')) {
      return Icons.wine_bar_outlined;
    }

    if (materiales.contains('carton') || materiales.contains('papel')) {
      return Icons.inventory_2_outlined;
    }

    return Icons.recycling_rounded;
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
