import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import 'importancia_reciclaje_screen.dart';
import 'login_screen.dart';
import 'mapa_screen.dart';
import 'tutorial_reciclaje_screen.dart';

class HomeScreen extends StatefulWidget {
  final String nombreUsuario;

  const HomeScreen({super.key, required this.nombreUsuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  File? _fotoCapturada;
  bool _capturando = false;
  bool _analizando = false;
  Map<String, dynamic>? _ultimoResultado;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Estadísticas de ejemplo (luego vendrán del backend)
  final int _objetosReciclados = 14;
  final Map<String, int> _materialesPorTipo = {
    'Plástico': 6,
    'Papel': 4,
    'Vidrio': 2,
    'Metal': 2,
  };

  final Map<String, IconData> _iconosMaterial = {
    'Plástico': Icons.water_drop_outlined,
    'Papel': Icons.article_outlined,
    'Vidrio': Icons.wine_bar_outlined,
    'Metal': Icons.hardware_outlined,
  };

  final Map<String, Color> _coloresMaterial = {
    'Plástico': const Color(0xFF4FC3F7),
    'Papel': const Color(0xFFA5D6A7),
    'Vidrio': const Color(0xFF80CBC4),
    'Metal': const Color(0xFFFFCC80),
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
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

  Future<void> _abrirCamara() async {
    setState(() => _capturando = true);

    try {
      final picker = ImagePicker();
      final XFile? foto = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85,
      );

      if (foto != null) {
        setState(() {
          _fotoCapturada = File(foto.path);
        });
        _mostrarFotoCapturada();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo acceder a la cámara'),
            backgroundColor: Colors.redAccent,
          ),
        );
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enviando imagen a la IA...'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_iaBaseUrl/clasificar/imagen'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', foto.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(data['detail'] ?? 'No se pudo analizar la imagen');
      }

      final resultado = Map<String, dynamic>.from(
        (data['resultado'] as Map?) ?? const <String, dynamic>{},
      );

      if (!mounted) return;

      setState(() {
        _ultimoResultado = resultado;
      });

      _mostrarResultadoAnalisis(resultado);
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo conectar con la IA en $_iaBaseUrl. Verifica que el servicio esté encendido y que el celular y tu PC estén en la misma red.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La IA tardó demasiado en responder. Revisa que el servidor esté activo e inténtalo de nuevo.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo analizar la imagen: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _analizando = false);
      }
    }
  }

  void _mostrarResultadoAnalisis(Map<String, dynamic> resultado) {
    final objeto = resultado['objeto_detectado']?.toString() ?? 'Objeto';
    final categoria = resultado['categoria']?.toString() ?? 'sin categoría';
    final accion = resultado['accion']?.toString() ?? 'sin acción';
    final instrucciones =
        resultado['instrucciones']?.toString() ?? 'Sin instrucciones';
    final confianza = ((resultado['confianza'] ?? 0) as num).toDouble();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF163525),
        title: const Text(
          'Resultado del análisis',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultadoLinea('Objeto', objeto),
            _buildResultadoLinea('Categoría', categoria),
            _buildResultadoLinea('Acción', accion),
            _buildResultadoLinea(
              'Confianza',
              '${(confianza * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 12),
            const Text(
              'Instrucciones',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(instrucciones, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultadoLinea(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFotoCapturada() {
    if (_fotoCapturada == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
              '¡Foto capturada!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lista para analizar',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.file(
                    _fotoCapturada!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() => _fotoCapturada = null);
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      label: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.white70),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _analizando ? null : _analizarImagen,
                      icon: _analizando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_analizando ? 'Analizando...' : 'Analizar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF43A047),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ────────────────────────────────────────
                _buildHeader(),

                const SizedBox(height: 32),

                // ─── BOTÓN ESCANEAR ─────────────────────────────────
                _buildBotonEscanear(),

                const SizedBox(height: 32),

                // ─── ESTADÍSTICAS ───────────────────────────────────
                _buildSeccionEstadisticas(),

                if (_ultimoResultado != null) ...[
                  const SizedBox(height: 24),
                  _buildUltimoResultado(),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════
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
                    'Hola, ${widget.nombreUsuario} 👋',
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
                // 🌍 BOTÓN MAPA
                Tooltip(
                  message: 'Ver puntos de reciclaje',
                  child: GestureDetector(
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
                ),

                Tooltip(
                  message: 'Cerrar sesión',
                  child: GestureDetector(
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
                ),

                // 🌱 ICONO ECO
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

  // ══════════════════════════════════════════
  //  BOTÓN ESCANEAR
  // ══════════════════════════════════════════
  Widget _buildBotonEscanear() {
    return Center(
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: GestureDetector(
              onTap: _capturando ? null : _abrirCamara,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF43A047).withOpacity(0.45),
                      blurRadius: 36,
                      spreadRadius: 4,
                    ),
                  ],
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
                            size: 64,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Escanear\nResiduo',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Toca para abrir la cámara',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SECCIÓN ESTADÍSTICAS
  // ══════════════════════════════════════════
  Widget _buildSeccionEstadisticas() {
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

        // Tarjeta total reciclados
        _buildTarjetaTotal(),

        const SizedBox(height: 16),

        // Materiales
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
          children: _materialesPorTipo.entries.map((entry) {
            return _buildTarjetaMaterial(
              entry.key,
              entry.value,
              _iconosMaterial[entry.key]!,
              _coloresMaterial[entry.key]!,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUltimoResultado() {
    final resultado = _ultimoResultado!;
    final categoria = resultado['categoria']?.toString() ?? 'sin categoría';
    final accion = resultado['accion']?.toString() ?? 'sin acción';
    final objeto = resultado['objeto_detectado']?.toString() ?? 'Objeto';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Último análisis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            objeto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Categoría: $categoria',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            'Acción recomendada: $accion',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaTotal() {
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
                '$_objetosReciclados',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Objetos reciclados',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaMaterial(
    String nombre,
    int cantidad,
    IconData icono,
    Color color,
  ) {
    final total = _materialesPorTipo.values.fold(0, (sum, v) => sum + v);
    final porcentaje = total > 0 ? (cantidad / total) : 0.0;

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
}
