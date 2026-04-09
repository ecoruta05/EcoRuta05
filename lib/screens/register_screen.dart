import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String ultimoCorreoConsultado = "";
  bool correoDisponible = false;
  bool verificandoCorreo = false;
  bool verificacionCorreoExitosa = false;
  bool tieneMinimo = false;
  bool tieneNumero = false;
  bool tieneLetra = false;
  bool passwordsIguales = false;
  bool correoValido = false;

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  // 🔥 VALIDAR PASSWORD
  void validarPassword(String value) {
    setState(() {
      tieneMinimo = value.length >= 6;
      tieneNumero = RegExp(r'[0-9]').hasMatch(value);
      tieneLetra = RegExp(r'[a-zA-Z]').hasMatch(value);
      passwordsIguales = _confirmPasswordController.text == value;
    });
  }

  // 🔥 VALIDAR CONFIRM PASSWORD
  void validarConfirmPassword(String value) {
    setState(() {
      passwordsIguales = value == _passwordController.text;
    });
  }

  // 🔥 VALIDAR CORREO
  Future<void> validarCorreo(String value) async {
    final correo = value.toLowerCase().trim();
    ultimoCorreoConsultado = correo;

    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');

    if (!regex.hasMatch(correo)) {
      setState(() {
        correoValido = false;
        correoDisponible = false;
        verificandoCorreo = false;
        verificacionCorreoExitosa = false;
      });
      return;
    }

    setState(() {
      correoValido = true;
      verificandoCorreo = true;
      verificacionCorreoExitosa = false;
    });

    try {
      final res = await http.get(
        Uri.parse(
          "${ApiConfig.authBaseUrl}/api/auth/check-email/${Uri.encodeComponent(correo)}",
        ),
      );

      final data = jsonDecode(res.body);

      if (correo != ultimoCorreoConsultado) return;

      setState(() {
        correoDisponible = !data["existe"];
        verificandoCorreo = false;
        verificacionCorreoExitosa = true;
      });
    } catch (e) {
      setState(() {
        verificandoCorreo = false;
        correoDisponible = false;
        verificacionCorreoExitosa = false;
      });
    }
  }

  Widget _buildRule(String text, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: ok ? Colors.green : Colors.red, fontSize: 13),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildEmailStatus() {
    return Row(
      children: [
        verificandoCorreo
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                (!correoValido || !correoDisponible)
                    ? Icons.cancel
                    : Icons.check_circle,
                color: (!correoValido || !correoDisponible)
                    ? Colors.red
                    : Colors.green,
                size: 18,
              ),
        const SizedBox(width: 8),
        Text(
          !correoValido
              ? "Debe ser @gmail.com"
              : verificandoCorreo
              ? "Verificando..."
              : !verificacionCorreoExitosa
              ? "No se pudo verificar"
              : correoDisponible
              ? "Disponible"
              : "Ya registrado",
          style: TextStyle(
            color: !correoValido
                ? Colors.red
                : verificandoCorreo
                ? Colors.white70
                : !verificacionCorreoExitosa
                ? Colors.orange
                : correoDisponible
                ? Colors.green
                : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRule("Minimo 6 caracteres", tieneMinimo),
        _buildRule("Contiene numero", tieneNumero),
        _buildRule("Contiene letra", tieneLetra),
      ],
    );
  }

  Widget _buildPasswordMatch() {
    return _buildRule(
      passwordsIguales ? "Las contrasenas coinciden" : "No coinciden",
      passwordsIguales,
    );
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (!correoValido) return;
      if (!verificacionCorreoExitosa) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo verificar el correo")),
        );
        return;
      }
      if (!correoDisponible) return;
      if (!tieneMinimo || !tieneNumero || !tieneLetra) return;
      if (!passwordsIguales) return;

      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse("${ApiConfig.authBaseUrl}/api/auth/registro"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "nombre": _nameController.text,
            "apellido": _lastNameController.text,
            "correo": _emailController.text.toLowerCase().trim(),
            "telefono": _phoneController.text,
            "password": _passwordController.text,
          }),
        );

        final data = jsonDecode(response.body);

        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Registro exitoso"),
              content: Text(data["mensaje"]),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(data["mensaje"])));
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 500
                      ? 400
                      : double.infinity,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person_add,
                          size: 50,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 10),

                        const Text(
                          "Crear Cuenta",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration("Nombre", Icons.person),
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _lastNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration("Apellido", Icons.person),
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _emailController,
                          onChanged: validarCorreo,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration("Correo", Icons.email),
                        ),

                        const SizedBox(height: 5),

                        if (_emailController.text.isNotEmpty)
                          _buildEmailStatus(),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration("Telefono", Icons.phone),
                        ),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          onChanged: validarPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration: _decoration("Contrasena", Icons.lock)
                              .copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isPasswordVisible = !_isPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                        ),

                        _buildPasswordRules(),

                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          onChanged: validarConfirmPassword,
                          style: const TextStyle(color: Colors.white),
                          decoration:
                              _decoration(
                                "Confirmar Contrasena",
                                Icons.lock,
                              ).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isConfirmPasswordVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible;
                                    });
                                  },
                                ),
                              ),
                        ),

                        if (_confirmPasswordController.text.isNotEmpty)
                          _buildPasswordMatch(),

                        const SizedBox(height: 15),

                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Registrarse",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),

                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Ya tienes cuenta? Inicia sesion",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

