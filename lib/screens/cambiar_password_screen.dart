import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class CambiarPasswordScreen extends StatefulWidget {
  final String token;

  const CambiarPasswordScreen({super.key, required this.token});

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final _passwordConfirmacionController = TextEditingController();

  bool _mostrarPasswordActual = false;
  bool _mostrarPasswordNueva = false;
  bool _mostrarPasswordConfirmacion = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    _passwordConfirmacionController.dispose();
    super.dispose();
  }

  Future<void> _actualizarPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse("${ApiConfig.authBaseUrl}/api/auth/cambiar-password");
      final body = jsonEncode({
        "passwordActual": _passwordActualController.text,
        "passwordNueva": _passwordNuevaController.text,
      });
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer ${widget.token}",
      };

      var response = await http
          .put(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));
      }

      final data = _parseResponseBody(response.body);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data["mensaje"]?.toString() ?? "Contraseña actualizada correctamente",
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data["mensaje"]?.toString() ??
                "No se pudo actualizar la contraseña (código ${response.statusCode})",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on SocketException {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de conexión con el servidor"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on HttpException {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error HTTP al cambiar la contraseña"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } on FormatException {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("El servidor respondió con un formato inválido"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No se pudo actualizar la contraseña: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Map<String, dynamic> _parseResponseBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{"mensaje": decoded.toString()};
    } catch (_) {
      return <String, dynamic>{"mensaje": body};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
        backgroundColor: const Color(0xFF1A3A2A),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A1F14), Color(0xFF0F2D1A), Color(0xFF1A3A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildCampoPassword(
                  controller: _passwordActualController,
                  label: 'Contraseña actual',
                  mostrar: _mostrarPasswordActual,
                  onToggle: () {
                    setState(() {
                      _mostrarPasswordActual = !_mostrarPasswordActual;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _buildCampoPassword(
                  controller: _passwordNuevaController,
                  label: 'Contraseña nueva',
                  mostrar: _mostrarPasswordNueva,
                  onToggle: () {
                    setState(() {
                      _mostrarPasswordNueva = !_mostrarPasswordNueva;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu nueva contraseña';
                    }
                    if (value.length < 6 ||
                        !RegExp(r'[A-Za-z]').hasMatch(value) ||
                        !RegExp(r'[0-9]').hasMatch(value)) {
                      return 'Mínimo 6 caracteres, una letra y un número';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _buildCampoPassword(
                  controller: _passwordConfirmacionController,
                  label: 'Confirmar contraseña nueva',
                  mostrar: _mostrarPasswordConfirmacion,
                  onToggle: () {
                    setState(() {
                      _mostrarPasswordConfirmacion =
                          !_mostrarPasswordConfirmacion;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma tu nueva contraseña';
                    }
                    if (value != _passwordNuevaController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _actualizarPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Actualizar contraseña',
                            style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildCampoPassword({
    required TextEditingController controller,
    required String label,
    required bool mostrar,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !mostrar,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            mostrar ? Icons.visibility : Icons.visibility_off,
            color: Colors.white70,
          ),
        ),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return 'Este campo es obligatorio';
            }
            return null;
          },
    );
  }
}
