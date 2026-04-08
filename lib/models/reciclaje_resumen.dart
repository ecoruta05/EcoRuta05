class ReciclajeResumen {
  const ReciclajeResumen({
    required this.kilosTotales,
    required this.dineroGanado,
    required this.puntosEco,
  });

  final double kilosTotales;
  final double dineroGanado;
  final int puntosEco;

  factory ReciclajeResumen.fromJson(Map<String, dynamic> json) {
    return ReciclajeResumen(
      kilosTotales: (json['kilosTotales'] as num?)?.toDouble() ?? 0,
      dineroGanado: (json['dineroGanado'] as num?)?.toDouble() ?? 0,
      puntosEco: (json['puntosEco'] as num?)?.toInt() ?? 0,
    );
  }

  const ReciclajeResumen.vacio()
      : kilosTotales = 0,
        dineroGanado = 0,
        puntosEco = 0;
}
