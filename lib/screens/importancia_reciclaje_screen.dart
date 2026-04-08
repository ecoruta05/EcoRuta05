import 'package:flutter/material.dart';

class ImportanciaReciclajeScreen extends StatelessWidget {
  const ImportanciaReciclajeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importancia del reciclaje'),
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
                  '¿Por que reciclar?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Reciclar reduce el impacto ambiental de nuestra basura y ayuda a cuidar los recursos naturales para las futuras generaciones.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                SizedBox(height: 22),
                _BeneficioCard(
                  icon: Icons.public_rounded,
                  title: 'Menos contaminacion',
                  description:
                      'Disminuye la basura en calles, rios y oceanos, y reduce la contaminacion del suelo y del aire.',
                ),
                SizedBox(height: 14),
                _BeneficioCard(
                  icon: Icons.forest_rounded,
                  title: 'Proteccion de ecosistemas',
                  description:
                      'Se reduce la extraccion de materias primas, la tala de bosques y el dano a habitats naturales.',
                ),
                SizedBox(height: 14),
                _BeneficioCard(
                  icon: Icons.bolt_rounded,
                  title: 'Ahorro de energia y agua',
                  description:
                      'Fabricar productos con material reciclado suele requerir menos energia y menos agua.',
                ),
                SizedBox(height: 14),
                _BeneficioCard(
                  icon: Icons.co2_rounded,
                  title: 'Menos emisiones de CO2',
                  description:
                      'El reciclaje ayuda a disminuir gases de efecto invernadero y aporta frente al cambio climatico.',
                ),
                SizedBox(height: 14),
                _BeneficioCard(
                  icon: Icons.groups_rounded,
                  title: 'Impacto social positivo',
                  description:
                      'Promueve cultura ambiental, genera empleos verdes y fortalece comunidades mas limpias.',
                ),
                SizedBox(height: 24),
                _ConsejoFinalCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BeneficioCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _BeneficioCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFA5D6A7)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsejoFinalCard extends StatelessWidget {
  const _ConsejoFinalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'Pequenas acciones diarias generan grandes cambios. Separar, limpiar y reciclar correctamente tu basura marca una diferencia real para el planeta.',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }
}
