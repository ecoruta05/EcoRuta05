import 'package:flutter/material.dart';

class ResiduosEspecialesScreen extends StatelessWidget {
  const ResiduosEspecialesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Residuos especiales'),
        backgroundColor: Colors.transparent,
      ),
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Informacion sobre residuos especiales',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Estos residuos no deben mezclarse con reciclables, organicos ni basura ordinaria. Requieren puntos de entrega o manejo especial.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                SizedBox(height: 20),
                _ResiduoEspecialCard(
                  icon: Icons.warning_amber_rounded,
                  color: Color(0xFFF9A825),
                  titulo: 'Peligrosos',
                  descripcion:
                      'Pilas, baterias, bombillos, pinturas, aerosoles, medicamentos vencidos y quimicos.',
                  nota:
                      'Pueden contaminar el agua, el suelo y representar riesgo para la salud.',
                ),
                SizedBox(height: 14),
                _ResiduoEspecialCard(
                  icon: Icons.devices_rounded,
                  color: Color(0xFF29B6F6),
                  titulo: 'Electronicos',
                  descripcion:
                      'Celulares, cargadores, computadores, teclados, cables y pequenos electrodomesticos.',
                  nota:
                      'Deben llevarse a puntos RAEE o jornadas de recoleccion tecnologica.',
                ),
                SizedBox(height: 14),
                _ResiduoEspecialCard(
                  icon: Icons.biotech_rounded,
                  color: Color(0xFFEF5350),
                  titulo: 'Biosanitarios',
                  descripcion:
                      'Tapabocas, guantes contaminados, jeringas, gasas y residuos de atencion en salud.',
                  nota:
                      'Necesitan un manejo controlado para evitar contagios o exposicion riesgosa.',
                ),
                SizedBox(height: 22),
                _EntregaEspecialCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResiduoEspecialCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String descripcion;
  final String nota;

  const _ResiduoEspecialCard({
    required this.icon,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.nota,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  descripcion,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    nota,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntregaEspecialCard extends StatelessWidget {
  const _EntregaEspecialCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Como entregarlos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            '• No los mezcles con otras canecas.\n• Guardalos por separado y, si aplica, bien cerrados.\n• Llevalos a puntos autorizados o programas especiales de recoleccion.',
            style: TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}
