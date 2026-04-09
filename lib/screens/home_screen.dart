import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../models/reciclaje_resumen.dart';
import 'importancia_reciclaje_screen.dart';
import 'login_screen.dart';
import 'mapa_screen.dart';
import 'qr_venta_screen.dart';
import 'tutorial_reciclaje_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.nombreUsuario,
    required this.authToken,
    required this.userId,
    required this.resumenInicial,
  });

  final String nombreUsuario;
  final String authToken;
  final String userId;
  final ReciclajeResumen resumenInicial;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  File? _fotoCapturada;
  bool _capturando = false;
  bool _analizando = false;
  bool _cargandoResumen = false;
  Map<String, dynamic>? _ultimoResultado;
  ReciclajeResumen _resumen = const ReciclajeResumen.vacio();
  List<Map<String, dynamic>> _ventasRecientes = const [];
  List<Map<String, dynamic>> _materialesDisponibles = const [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final NumberFormat _formatoMiles = NumberFormat.decimalPattern('es_CO');

  Map<String, double> get _kilosPorMaterial {
    final acumulado = <String, double>{};

    for (final venta in _ventasRecientes) {
      final materiales = venta['materiales'] as List? ?? const [];
      for (final item in materiales) {
        final material = Map<String, dynamic>.from(item as Map);
        final nombre = material['nombre']?.toString().trim() ?? '';
        final kilos = (material['kilos'] as num?)?.toDouble() ?? 0;
        if (nombre.isEmpty || kilos <= 0) continue;
        acumulado[nombre] = (acumulado[nombre] ?? 0) + kilos;
      }
    }

    final entradas = acumulado.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final item in entradas) item.key: item.value};
  }

  Map<String, int> get _conteoPorMaterial {
    final acumulado = <String, int>{};

    for (final venta in _ventasRecientes) {
      final materiales = venta['materiales'] as List? ?? const [];
      for (final item in materiales) {
        final material = Map<String, dynamic>.from(item as Map);
        final nombre = material['nombre']?.toString().trim() ?? '';
        if (nombre.isEmpty) continue;
        acumulado[nombre] = (acumulado[nombre] ?? 0) + 1;
      }
    }

    final entradas = acumulado.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final item in entradas) item.key: item.value};
  }

  int get _totalRegistrosMaterial {
    return _conteoPorMaterial.values.fold<int>(0, (sum, value) => sum + value);
  }

  IconData _iconoMaterial(String material) {
    switch (material.toLowerCase()) {
      case 'plastico':
        return Icons.water_drop_outlined;
      case 'papel':
      case 'carton':
        return Icons.article_outlined;
      case 'vidrio':
        return Icons.wine_bar_outlined;
      case 'metal':
      case 'aluminio':
      case 'cobre':
      case 'latas':
        return Icons.hardware_outlined;
      default:
        return Icons.recycling_outlined;
    }
  }

  Color _colorMaterial(String material) {
    switch (material.toLowerCase()) {
      case 'plastico':
        return const Color(0xFF4FC3F7);
      case 'papel':
      case 'carton':
        return const Color(0xFFA5D6A7);
      case 'vidrio':
        return const Color(0xFF80CBC4);
      case 'metal':
      case 'aluminio':
      case 'cobre':
      case 'latas':
        return const Color(0xFFFFCC80);
      default:
        return const Color(0xFF81C784);
    }
  }

  String _formatearDinero(num valor) {
    return _formatoMiles.format(valor.round());
  }

  void _formatearEntradaDinero(TextEditingController controller) {
    final soloDigitos = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) {
      controller.value = const TextEditingValue(text: '');
      return;
    }

    final texto = _formatoMiles.format(int.parse(soloDigitos));
    controller.value = TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }

  @override
  void initState() {
    super.initState();
    _resumen = widget.resumenInicial;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String get _iaBaseUrl => ApiConfig.iaBaseUrl;

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF163525),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          '¿Seguro que deseas cerrar sesión?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _cargarDatosIniciales() async {
    await Future.wait([_cargarResumenReciclaje(), _cargarMaterialesPuntaje()]);
  }

  Future<void> _cargarResumenReciclaje() async {
    if (widget.authToken.isEmpty) return;
    setState(() => _cargandoResumen = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.authBaseUrl}/api/ventas-reciclaje/resumen'),
        headers: {'Authorization': 'Bearer ${widget.authToken}'},
      );
      if (response.statusCode != 200) {
        throw Exception('Error cargando resumen');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;

      setState(() {
        _resumen = ReciclajeResumen.fromJson(
          Map<String, dynamic>.from(
            data['resumen'] as Map? ?? const <String, dynamic>{},
          ),
        );
        _ventasRecientes = (data['ventas'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el resumen.')),
      );
    } finally {
      if (mounted) setState(() => _cargandoResumen = false);
    }
  }

  Future<void> _cargarMaterialesPuntaje() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.authBaseUrl}/api/materiales-puntaje'),
      );
      if (response.statusCode != 200) {
        throw Exception('Error cargando materiales');
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _materialesDisponibles = data
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo cargar la lista de materiales.'),
        ),
      );
    }
  }

  Future<void> _escanearQrVenta() async {
    final qrContenido = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrVentaScreen()),
    );

    if (!mounted || qrContenido == null || qrContenido.trim().isEmpty) return;
    await _mostrarFormularioVenta(qrContenido);
  }

  Future<void> _mostrarFormularioVenta(String qrContenido) async {
    final formKey = GlobalKey<FormState>();
    bool guardando = false;
    if (_materialesDisponibles.isEmpty) {
      await _cargarMaterialesPuntaje();
    }

    final materiales = <Map<String, dynamic>>[
      {
        'nombre': _materialesDisponibles.isNotEmpty
            ? _materialesDisponibles.first['material']?.toString() ?? ''
            : '',
        'kilos': TextEditingController(),
        'valor': TextEditingController(),
      },
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> registrar() async {
            if (!formKey.currentState!.validate()) return;
            setModalState(() => guardando = true);

            try {
              final materialesPayload = materiales
                  .map(
                    (item) => ({
                      'nombre': item['nombre']?.toString() ?? '',
                      'kilos': double.parse(
                        (item['kilos'] as TextEditingController).text
                            .trim()
                            .replaceAll(',', '.'),
                      ),
                      'valorGanado': double.parse(
                        (item['valor'] as TextEditingController).text
                            .replaceAll('.', '')
                            .replaceAll(',', '')
                            .trim(),
                      ),
                    }),
                  )
                  .toList();

              final response = await http.post(
                Uri.parse(
                  '${ApiConfig.authBaseUrl}/api/ventas-reciclaje/registrar',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${widget.authToken}',
                },
                body: jsonEncode({
                  'qrContenido': qrContenido,
                  'materiales': materialesPayload,
                }),
              );

              final data = jsonDecode(response.body) as Map<String, dynamic>;
              if (response.statusCode != 201) {
                throw Exception(data['mensaje'] ?? 'No se pudo guardar');
              }

              if (!mounted) return;
              setState(() {
                _resumen = ReciclajeResumen.fromJson(
                  Map<String, dynamic>.from(
                    data['resumen'] as Map? ?? const <String, dynamic>{},
                  ),
                );
                _ventasRecientes = [
                  Map<String, dynamic>.from(
                    data['venta'] as Map? ?? const <String, dynamic>{},
                  ),
                  ..._ventasRecientes,
                ].take(10).toList();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(
                  content: Text('Venta registrada correctamente.'),
                  backgroundColor: Color(0xFF2E7D32),
                ),
              );
            } catch (error) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('No se pudo registrar la venta: $error'),
                ),
              );
            } finally {
              if (context.mounted) setModalState(() => guardando = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF163525),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Registrar venta por QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Materiales entregados',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(materiales.length, (index) {
                        final item = materiales[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value:
                                      (item['nombre']?.toString().isNotEmpty ??
                                          false)
                                      ? item['nombre'] as String
                                      : null,
                                  dropdownColor: const Color(0xFF163525),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration(
                                    'Material ${index + 1}',
                                  ),
                                  items: _materialesDisponibles
                                      .map(
                                        (material) => DropdownMenuItem<String>(
                                          value:
                                              material['material']
                                                  ?.toString() ??
                                              '',
                                          child: Text(
                                            material['material']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setModalState(() {
                                      item['nombre'] = value ?? '';
                                    });
                                  },
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Selecciona el material';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller:
                                      item['kilos'] as TextEditingController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('Kilos'),
                                  validator: (value) {
                                    final n = double.tryParse(
                                      (value ?? '').replaceAll(',', '.'),
                                    );
                                    return (n == null || n <= 0)
                                        ? 'Ingresa kilos válidos'
                                        : null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller:
                                      item['valor'] as TextEditingController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _inputDecoration('Dinero ganado'),
                                  onChanged: (_) => _formatearEntradaDinero(
                                    item['valor'] as TextEditingController,
                                  ),
                                  validator: (value) {
                                    final n = double.tryParse(
                                      (value ?? '')
                                          .replaceAll('.', '')
                                          .replaceAll(',', ''),
                                    );
                                    return (n == null || n < 0)
                                        ? 'Ingresa un valor válido'
                                        : null;
                                  },
                                ),
                                if (materiales.length > 1) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        setModalState(() {
                                          materiales.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white70,
                                      ),
                                      label: const Text(
                                        'Quitar',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      TextButton.icon(
                        onPressed: () {
                          setModalState(() {
                            materiales.add({
                              'nombre': _materialesDisponibles.isNotEmpty
                                  ? _materialesDisponibles.first['material']
                                            ?.toString() ??
                                        ''
                                  : '',
                              'kilos': TextEditingController(),
                              'valor': TextEditingController(),
                            });
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: Color(0xFF9BE7A1),
                        ),
                        label: const Text(
                          'Agregar otro material',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: guardando ? null : registrar,
                          icon: guardando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.qr_code_scanner_rounded),
                          label: Text(
                            guardando ? 'Guardando...' : 'Guardar venta',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF43A047),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _abrirCamara() async {
    setState(() => _capturando = true);
    try {
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );
      if (foto != null) {
        setState(() => _fotoCapturada = File(foto.path));
        _mostrarFotoCapturada();
      }
    } finally {
      if (mounted) setState(() => _capturando = false);
    }
  }

  Future<void> _analizarImagen() async {
    final foto = _fotoCapturada;
    if (foto == null || _analizando) return;

    Navigator.pop(context);
    setState(() => _analizando = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_iaBaseUrl/clasificar/imagen'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', foto.path));

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);
      final data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(data['detail'] ?? 'No se pudo analizar la imagen');
      }

      if (!mounted) return;
      setState(() {
        _ultimoResultado = Map<String, dynamic>.from(
          (data['resultado'] as Map?) ?? const <String, dynamic>{},
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo analizar la imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _analizando = false);
    }
  }

  void _mostrarFotoCapturada() {
    if (_fotoCapturada == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1A3A2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Foto capturada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(_fotoCapturada!, fit: BoxFit.cover),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _fotoCapturada = null);
                      },
                      child: const Text('Reintentar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _analizando ? null : _analizarImagen,
                      child: Text(_analizando ? 'Analizando...' : 'Analizar'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1F14), Color(0xFF0F2D1A), Color(0xFF1A3A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildBotonEscanearResiduo(),
                const SizedBox(height: 28),
                _buildSeccionEstadisticasClasica(),
                const SizedBox(height: 14),
                _buildCardRegistrarVenta(),
                const SizedBox(height: 28),
                _buildResumenVentas(),
                if (_kilosPorMaterial.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildEstadisticasMateriales(),
                ],
                if (_ventasRecientes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildVentasRecientes(),
                ],
                if (_ultimoResultado != null) ...[
                  const SizedBox(height: 24),
                  _buildUltimoResultado(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Hola, ${widget.nombreUsuario}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '¿Qué vas a reciclar hoy?',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapaScreen()),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      color: Color(0xFF66BB6A),
                      size: 26,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cerrarSesion,
                  child: Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFFFB74D),
                      size: 24,
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Color(0xFF66BB6A),
                    size: 26,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildPestanasEducativas(),
      ],
    );
  }

  Widget _buildPestanasEducativas() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPestanaModulo(
            icon: Icons.public_rounded,
            titulo: 'Importancia',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ImportanciaReciclajeScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildPestanaModulo(
            icon: Icons.menu_book_rounded,
            titulo: 'Tutorial',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TutorialReciclajeScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPestanaModulo({
    required IconData icon,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF81C784), size: 18),
            const SizedBox(width: 7),
            Text(
              titulo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonEscanearResiduo() {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: GestureDetector(
          onTap: _capturando ? null : _abrirCamara,
          child: Container(
            width: 170,
            height: 170,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
              ),
            ),
            child: _capturando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.document_scanner_rounded,
                        color: Colors.white,
                        size: 58,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Escanear\nResiduo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardRegistrarVenta() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF43A047).withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Color(0xFF9BE7A1),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar venta',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Escanea el QR del comprador y registra materiales, kilos y dinero ganado.',
                  style: TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _escanearQrVenta,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Escanear'),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenVentas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mi resumen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_cargandoResumen)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTarjetaPrincipal(),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMiniTarjeta(
                'Kilos',
                _resumen.kilosTotales.toStringAsFixed(1),
                Icons.scale_outlined,
                const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMiniTarjeta(
                'Puntos',
                '${_resumen.puntosEco}',
                Icons.stars_rounded,
                const Color(0xFFFFB300),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: const Text(
            'Tus puntos se podrán redimir por convenios. Cada kilo registrado suma puntos automáticamente.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionEstadisticasClasica() {
    final materiales = _conteoPorMaterial.entries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mis estadísticas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildTarjetaTotalClasica(),
        if (materiales.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Por tipo de material',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: materiales
                .map(
                  (entry) => _buildTarjetaMaterialClasica(
                    entry.key,
                    entry.value,
                    _iconoMaterial(entry.key),
                    _colorMaterial(entry.key),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTarjetaTotalClasica() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.recycling_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_totalRegistrosMaterial',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Materiales registrados',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaMaterialClasica(
    String nombre,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    final total = _conteoPorMaterial.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final porcentaje = total > 0 ? cantidad / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              Text(
                '$cantidad',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: porcentaje,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasMateriales() {
    final materiales = _kilosPorMaterial.entries.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Por material',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: materiales
              .map(
                (entry) => _buildTarjetaMaterial(
                  entry.key,
                  entry.value,
                  _iconoMaterial(entry.key),
                  _colorMaterial(entry.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTarjetaPrincipal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.savings_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$ ${_formatearDinero(_resumen.dineroGanado)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dinero ganado',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTarjeta(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(titulo, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildTarjetaMaterial(
    String nombre,
    double kilos,
    IconData icono,
    Color color,
  ) {
    final total = _kilosPorMaterial.values.fold<double>(0, (sum, v) => sum + v);
    final porcentaje = total > 0 ? kilos / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              Text(
                '${kilos.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: porcentaje,
                  minHeight: 4,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVentasRecientes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Últimas ventas',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._ventasRecientes.take(3).map((venta) {
          final kilos = (venta['kilos'] as num?)?.toDouble() ?? 0;
          final dinero = (venta['valorGanado'] as num?)?.toDouble() ?? 0;
          final puntos = (venta['puntosGanados'] as num?)?.toInt() ?? 0;
          final nombre = venta['puntoCompraNombre']?.toString() ?? 'Punto';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              '$nombre\n${kilos.toStringAsFixed(1)} kg | \$ ${_formatearDinero(dinero)} | +$puntos puntos',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildUltimoResultado() {
    final resultado = _ultimoResultado!;
    final objeto = resultado['objeto_detectado']?.toString() ?? 'Objeto';
    final categoria = resultado['categoria']?.toString() ?? 'sin categoría';
    final accion = resultado['accion']?.toString() ?? 'sin acción';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        'Último análisis\n$objeto\nCategoría: $categoria\nAcción: $accion',
        style: const TextStyle(color: Colors.white70, height: 1.5),
      ),
    );
  }
}
