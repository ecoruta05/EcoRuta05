import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/punto_compra.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _busquedaController = TextEditingController();
  final LatLng _villavicencio = const LatLng(4.1420, -73.6266);
  static const double _zoomPuntoSeleccionado = 15;

  LatLng? _miUbicacion;
  PuntoCompra? _puntoSeleccionado;
  List<PuntoCompra> _puntosCompra = const [];

  bool _cargandoUbicacion = true;
  bool _cargandoPuntos = true;
  String? _mensajeUbicacion;
  String? _mensajePuntos;
  String _busqueda = '';

  List<PuntoCompra> get _puntosFiltrados {
    final termino = _busqueda.trim().toLowerCase();
    if (termino.isEmpty) return _puntosCompra;

    return _puntosCompra.where((punto) {
      final materiales = punto.materialesCompra.join(' ').toLowerCase();
      return punto.nombre.toLowerCase().contains(termino) ||
          punto.barrio.toLowerCase().contains(termino) ||
          punto.direccion.toLowerCase().contains(termino) ||
          punto.referencia.toLowerCase().contains(termino) ||
          materiales.contains(termino);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _cargarPantalla();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
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

      setState(() {
        _miUbicacion = LatLng(posicion.latitude, posicion.longitude);
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
        _cargandoPuntos = false;
      });
      _asegurarSeleccionValida(centrarSiCambia: false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoPuntos = false;
        _mensajePuntos =
            'No se pudieron cargar los puntos de compra desde el backend.';
      });
    }
  }

  void _actualizarBusqueda(String valor) {
    setState(() {
      _busqueda = valor;
    });
    _asegurarSeleccionValida();
  }

  void _asegurarSeleccionValida({bool centrarSiCambia = true}) {
    final visibles = _puntosFiltrados;
    if (visibles.isEmpty) {
      if (_puntoSeleccionado != null) {
        setState(() => _puntoSeleccionado = null);
      }
      return;
    }

    final seleccionActual = _puntoSeleccionado;
    final existeSeleccion =
        seleccionActual != null && visibles.any((item) => item.id == seleccionActual.id);

    if (existeSeleccion) return;

    final nuevoSeleccionado = visibles.first;
    setState(() => _puntoSeleccionado = nuevoSeleccionado);
    if (centrarSiCambia) {
      _mapController.move(nuevoSeleccionado.ubicacion, _zoomPuntoSeleccionado);
    }
  }

  void _seleccionarPunto(PuntoCompra punto) {
    setState(() => _puntoSeleccionado = punto);
    _mapController.move(punto.ubicacion, _zoomPuntoSeleccionado);
  }

  int get _indicePuntoSeleccionado {
    final punto = _puntoSeleccionado;
    if (punto == null) return -1;
    return _puntosFiltrados.indexWhere((item) => item.id == punto.id);
  }

  void _seleccionarPuntoPorIndice(int indice) {
    final puntosVisibles = _puntosFiltrados;
    if (indice < 0 || indice >= puntosVisibles.length) return;
    _seleccionarPunto(puntosVisibles[indice]);
  }

  void _irAlPuntoAnterior() {
    final puntosVisibles = _puntosFiltrados;
    if (puntosVisibles.length <= 1) return;
    final indiceActual = _indicePuntoSeleccionado;
    final indiceAnterior =
        indiceActual <= 0 ? puntosVisibles.length - 1 : indiceActual - 1;
    _seleccionarPuntoPorIndice(indiceAnterior);
  }

  void _irAlPuntoSiguiente() {
    final puntosVisibles = _puntosFiltrados;
    if (puntosVisibles.length <= 1) return;
    final indiceActual = _indicePuntoSeleccionado;
    final indiceSiguiente =
        indiceActual == -1 || indiceActual >= puntosVisibles.length - 1
            ? 0
            : indiceActual + 1;
    _seleccionarPuntoPorIndice(indiceSiguiente);
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
    final visibles = _puntosFiltrados;
    if (visibles.isEmpty && _miUbicacion == null) {
      return;
    }

    final bounds = LatLngBounds.fromPoints([
      ...visibles.map((p) => p.ubicacion),
      if (_miUbicacion != null) _miUbicacion!,
    ]);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(44, 44, 120, 260),
      ),
    );
  }

  Future<void> _abrirComoLlegar(PuntoCompra punto) async {
    final lat = punto.ubicacion.latitude;
    final lng = punto.ubicacion.longitude;
    final destino = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

    if (!await launchUrl(destino, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir Google Maps en este momento.'),
        ),
      );
    }
  }

  double? _distanciaKm(PuntoCompra punto) {
    final ubicacion = _miUbicacion;
    if (ubicacion == null) return null;

    final metros = Geolocator.distanceBetween(
      ubicacion.latitude,
      ubicacion.longitude,
      punto.ubicacion.latitude,
      punto.ubicacion.longitude,
    );

    return metros / 1000;
  }

  bool? _estaAbiertoAhora(PuntoCompra punto) {
    final texto = punto.horario.toLowerCase();
    final match = RegExp(
      r'(\d{1,2}:\d{2})\s*([ap])\.\s*m\.\s*-\s*(\d{1,2}:\d{2})\s*([ap])\.\s*m\.',
    ).firstMatch(texto);

    if (match == null) return null;

    final ahora = DateTime.now();
    final apertura = _convertirHora(match.group(1)!, match.group(2)!);
    final cierre = _convertirHora(match.group(3)!, match.group(4)!);
    final minutosActuales = ahora.hour * 60 + ahora.minute;

    final diasActivos = _diasActivos(texto);
    if (diasActivos != null && !diasActivos.contains(ahora.weekday)) {
      return false;
    }

    return minutosActuales >= apertura && minutosActuales <= cierre;
  }

  int _convertirHora(String hora, String periodo) {
    final partes = hora.split(':');
    var horas = int.parse(partes[0]);
    final minutos = int.parse(partes[1]);
    final esPm = periodo == 'p';

    if (esPm && horas != 12) horas += 12;
    if (!esPm && horas == 12) horas = 0;

    return horas * 60 + minutos;
  }

  Set<int>? _diasActivos(String horario) {
    if (horario.contains('lunes a sabado')) {
      return {1, 2, 3, 4, 5, 6};
    }
    if (horario.contains('lunes a viernes')) {
      return {1, 2, 3, 4, 5};
    }
    if (horario.contains('lunes a domingo')) {
      return {1, 2, 3, 4, 5, 6, 7};
    }
    if (horario.contains('sabado y domingo')) {
      return {6, 7};
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final puntosVisibles = _puntosFiltrados;

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
              MarkerLayer(markers: _buildMarkers(puntosVisibles)),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                _buildBuscador(),
                const SizedBox(height: 12),
                _buildEstadoUbicacion(),
                if (_buildEstadoUbicacion() is! SizedBox) const SizedBox(height: 12),
                _buildEstadoPuntos(),
                const SizedBox(height: 12),
                _buildResumenPuntos(puntosVisibles.length),
              ],
            ),
          ),
          _buildPanelArrastrable(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 170),
        child: Column(
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
      ),
    );
  }

  List<Marker> _buildMarkers(List<PuntoCompra> puntosVisibles) {
    return [
      ...puntosVisibles.map((punto) {
        final seleccionado = _puntoSeleccionado?.id == punto.id;
        return Marker(
          point: punto.ubicacion,
          width: seleccionado ? 58 : 46,
          height: seleccionado ? 58 : 46,
          child: GestureDetector(
            onTap: () => _seleccionarPunto(punto),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _colorPorMaterial(punto).withOpacity(seleccionado ? 0.96 : 0.8),
                border: Border.all(
                  color: seleccionado ? Colors.white : Colors.white70,
                  width: seleccionado ? 2.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _colorPorMaterial(punto).withOpacity(0.28),
                    blurRadius: seleccionado ? 10 : 6,
                  ),
                ],
              ),
              child: Icon(
                _iconoPorMaterial(punto),
                color: Colors.white,
                size: seleccionado ? 20 : 16,
              ),
            ),
          ),
        );
      }),
      if (_miUbicacion != null)
        Marker(
          point: _miUbicacion!,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1565C0).withOpacity(0.92),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.my_location,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
    ];
  }

  Widget _buildBuscador() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2193127),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _busquedaController,
        onChanged: _actualizarBusqueda,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, barrio o material',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _busquedaController.clear();
                    _actualizarBusqueda('');
                  },
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
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

  Widget _buildResumenPuntos(int cantidadVisible) {
    final mostrandoFiltro = _busqueda.trim().isNotEmpty;
    final texto = mostrandoFiltro
        ? '$cantidadVisible resultados de ${_puntosCompra.length} puntos'
        : '$cantidadVisible puntos de compra cargados para Villavicencio';

    return _InfoCard(
      color: const Color(0xCC163525),
      child: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Color(0xFF81C784)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
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

  Widget _buildPanelArrastrable() {
    return DraggableScrollableSheet(
      initialChildSize: 0.23,
      minChildSize: 0.18,
      maxChildSize: 0.58,
      builder: (context, scrollController) {
        final punto = _puntoSeleccionado;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xF110281D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.32),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: punto == null
              ? ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                  children: const [
                    Center(
                      child: _SheetHandle(),
                    ),
                    SizedBox(height: 18),
                    Text(
                      'Selecciona un punto en el mapa o usa el buscador para ver materiales, distancia y como llegar.',
                      style: TextStyle(color: Colors.white70, height: 1.4),
                    ),
                  ],
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
                  children: [
                    const Center(child: _SheetHandle()),
                    const SizedBox(height: 14),
                    _buildCabeceraPanel(punto),
                    const SizedBox(height: 14),
                    _buildResumenRapido(punto),
                    const SizedBox(height: 14),
                    _buildAccionesPanel(punto),
                    const SizedBox(height: 16),
                    _buildDetalle(icono: Icons.location_on_outlined, texto: punto.barrio),
                    if (punto.referencia.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildDetalle(
                        icono: Icons.place_outlined,
                        texto: punto.referencia,
                      ),
                    ],
                    const SizedBox(height: 10),
                    _buildDetalle(
                      icono: Icons.schedule_rounded,
                      texto: punto.horario,
                    ),
                    if (punto.telefono.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildDetalle(
                        icono: Icons.phone_outlined,
                        texto: punto.telefono,
                      ),
                    ],
                    if (punto.descripcion.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildDetalle(
                        icono: Icons.info_outline_rounded,
                        texto: punto.descripcion,
                      ),
                    ],
                    const SizedBox(height: 16),
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
                                horizontal: 11,
                                vertical: 7,
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
                                  fontSize: 12.5,
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
      },
    );
  }

  Widget _buildCabeceraPanel(PuntoCompra punto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _colorPorMaterial(punto).withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _iconoPorMaterial(punto),
            color: _colorPorMaterial(punto),
            size: 19,
          ),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                punto.direccion,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResumenRapido(PuntoCompra punto) {
    final abierto = _estaAbiertoAhora(punto);
    final distancia = _distanciaKm(punto);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (abierto != null)
          _buildChipEstado(
            icono: abierto ? Icons.check_circle_outline : Icons.access_time_rounded,
            texto: abierto ? 'Abierto ahora' : 'Cerrado',
            color: abierto ? const Color(0xFF43A047) : const Color(0xFFE65100),
          ),
        if (distancia != null)
          _buildChipEstado(
            icono: Icons.near_me_rounded,
            texto: '${distancia.toStringAsFixed(distancia < 10 ? 1 : 0)} km',
            color: const Color(0xFF1565C0),
          ),
        _buildChipEstado(
          icono: Icons.layers_outlined,
          texto: '${punto.materialesCompra.length} materiales',
          color: const Color(0xFF6D4C41),
        ),
      ],
    );
  }

  Widget _buildAccionesPanel(PuntoCompra punto) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _abrirComoLlegar(punto),
            icon: const Icon(Icons.route_rounded),
            label: const Text('Como llegar'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildBotonFlecha(
          icono: Icons.chevron_left_rounded,
          onTap: _irAlPuntoAnterior,
        ),
        const SizedBox(width: 6),
        _buildBotonFlecha(
          icono: Icons.chevron_right_rounded,
          onTap: _irAlPuntoSiguiente,
        ),
      ],
    );
  }

  Widget _buildChipEstado({
    required IconData icono,
    required String texto,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonFlecha({
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icono, color: Colors.white70, size: 22),
      ),
    );
  }

  Widget _buildDetalle({required IconData icono, required String texto}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, color: Colors.white70, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
