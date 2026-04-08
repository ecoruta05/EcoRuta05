import PuntoCompra from "../models/puntoCompra.js";

export const listarPuntosCompra = async (req, res) => {
  try {
    const ciudad = (req.query.ciudad || "Villavicencio").trim();

    const puntos = await PuntoCompra.find({
      ciudad,
      activo: true,
    })
      .sort({ nombre: 1 })
      .lean();

    return res.json(
      puntos.map((punto) => ({
        id: punto._id,
        nombre: punto.nombre,
        ciudad: punto.ciudad,
        barrio: punto.barrio,
        direccion: punto.direccion,
        referencia: punto.referencia,
        horario: punto.horario,
        telefono: punto.telefono,
        descripcion: punto.descripcion,
        materialesCompra: punto.materialesCompra,
        activo: punto.activo,
        latitud: punto.ubicacion?.coordinates?.[1] ?? null,
        longitud: punto.ubicacion?.coordinates?.[0] ?? null,
      }))
    );
  } catch (error) {
    console.error("Error listando puntos de compra:", error);
    return res.status(500).json({
      mensaje: "Error obteniendo puntos de compra",
    });
  }
};

export const obtenerPuntoCompra = async (req, res) => {
  try {
    const punto = await PuntoCompra.findById(req.params.id).lean();

    if (!punto || !punto.activo || punto.ciudad !== "Villavicencio") {
      return res.status(404).json({
        mensaje: "Punto de compra no encontrado",
      });
    }

    return res.json({
      id: punto._id,
      nombre: punto.nombre,
      ciudad: punto.ciudad,
      barrio: punto.barrio,
      direccion: punto.direccion,
      referencia: punto.referencia,
      horario: punto.horario,
      telefono: punto.telefono,
      descripcion: punto.descripcion,
      materialesCompra: punto.materialesCompra,
      activo: punto.activo,
      latitud: punto.ubicacion?.coordinates?.[1] ?? null,
      longitud: punto.ubicacion?.coordinates?.[0] ?? null,
    });
  } catch (error) {
    console.error("Error obteniendo punto de compra:", error);
    return res.status(500).json({
      mensaje: "Error obteniendo el punto de compra",
    });
  }
};
