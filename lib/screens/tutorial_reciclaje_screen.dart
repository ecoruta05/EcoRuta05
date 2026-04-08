import 'package:flutter/material.dart';

class TutorialReciclajeScreen extends StatelessWidget {
  const TutorialReciclajeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorial de reciclaje en casa'),
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
                  'Aprende a reciclar en 6 pasos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Sigue esta guia practica para manejar tu basura de forma responsable desde casa.',
                  style: TextStyle(color: Colors.white70, height: 1.45),
                ),
                SizedBox(height: 20),
                _PasoCard(
                  numero: 1,
                  titulo: 'Separa los residuos',
                  descripcion:
                      'Clasifica en plastico, papel/carton, vidrio, metal y organicos. Si puedes, usa contenedores de colores.',
                ),
                SizedBox(height: 12),
                _PasoCard(
                  numero: 2,
                  titulo: 'Limpia y seca envases',
                  descripcion:
                      'Enjuaga botellas, latas y recipientes para evitar malos olores y que se contaminen otros materiales.',
                ),
                SizedBox(height: 12),
                _PasoCard(
                  numero: 3,
                  titulo: 'Reduce volumen',
                  descripcion:
                      'Aplasta botellas plasticas y dobla carton para ahorrar espacio y facilitar el transporte.',
                ),
                SizedBox(height: 12),
                _PasoCard(
                  numero: 4,
                  titulo: 'Evita mezclar residuos sucios',
                  descripcion:
                      'Una pizza grasosa o un carton mojado pueden volver no reciclable todo el lote.',
                ),
                SizedBox(height: 12),
                _PasoCard(
                  numero: 5,
                  titulo: 'Identifica puntos de acopio',
                  descripcion:
                      'Usa el mapa de EcoRuta para ubicar centros cercanos y entregar cada material donde corresponde.',
                ),
                SizedBox(height: 12),
                _PasoCard(
                  numero: 6,
                  titulo: 'Hazlo un habito semanal',
                  descripcion:
                      'Define un dia fijo para revisar, separar y llevar residuos. La constancia es la clave.',
                ),
                SizedBox(height: 22),
                _TipsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasoCard extends StatelessWidget {
  final int numero;
  final String titulo;
  final String descripcion;

  const _PasoCard({
    required this.numero,
    required this.titulo,
    required this.descripcion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF66BB6A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
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

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Consejos rapidos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '• Si tienes dudas sobre un residuo, no lo mezcles hasta confirmarlo.\n• Reutiliza frascos y bolsas cuando sea posible.\n• Involucra a toda la familia para mantener el habito.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
        ],
      ),
    );
  }
}
