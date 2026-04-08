import 'package:latlong2/latlong.dart';

class PuntoCompra {
  const PuntoCompra({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.barrio,
    required this.direccion,
    required this.referencia,
    required this.horario,
    required this.telefono,
    required this.descripcion,
    required this.materialesCompra,
    required this.ubicacion,
  });

  final String id;
  final String nombre;
  final String ciudad;
  final String barrio;
  final String direccion;
  final String referencia;
  final String horario;
  final String telefono;
  final String descripcion;
  final List<String> materialesCompra;
  final LatLng ubicacion;

  factory PuntoCompra.fromJson(Map<String, dynamic> json) {
    final ubicacionJson = json['ubicacion'] as Map<String, dynamic>?;
    final coordinates = ubicacionJson?['coordinates'] as List?;

    final latitud = (json['latitud'] as num?)?.toDouble() ??
        (coordinates != null && coordinates.length >= 2
            ? (coordinates[1] as num?)?.toDouble() ?? 0
            : 0);
    final longitud = (json['longitud'] as num?)?.toDouble() ??
        (coordinates != null && coordinates.isNotEmpty
            ? (coordinates[0] as num?)?.toDouble() ?? 0
            : 0);

    return PuntoCompra(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? 'Sin nombre',
      ciudad: json['ciudad']?.toString() ?? 'Villavicencio',
      barrio: json['barrio']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      referencia: json['referencia']?.toString() ?? '',
      horario: json['horario']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      materialesCompra: (json['materialesCompra'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      ubicacion: LatLng(latitud, longitud),
    );
  }
}
