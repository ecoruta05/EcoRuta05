import MaterialPuntaje from "../models/materialPuntaje.js";
import PuntoCompra from "../models/puntoCompra.js";
import ResumenReciclaje from "../models/resumenReciclaje.js";
import Usuario from "../models/user.js";
import VentaReciclaje from "../models/ventaReciclaje.js";

const normalizarNombreMaterial = (nombreMaterial) => {
  const nombre = nombreMaterial?.toString().trim();

  if (!nombre) return "";

  const normalizado = nombre.toLowerCase();
  const aliasMetal = new Set([
    "metal",
    "hierro",
    "acero",
    "chatarra",
    "chatarra liviana"
  ]);

  if (aliasMetal.has(normalizado)) {
    return "Metal";
  }

  if (normalizado === "lata" || normalizado === "latas") {
    return "Latas";
  }

  return nombre;
};

const extraerIdPuntoDesdeQr = (qrContenido) => {
  const texto = qrContenido?.trim();

  if (!texto) return null;

  try {
    const data = JSON.parse(texto);
    return data?.puntoCompraId || data?.id || null;
  } catch (_) {
    return texto;
  }
};

export const obtenerResumenReciclaje = async (req, res) => {
  try {
    const usuario = await Usuario.findById(req.usuario.id).lean();

    if (!usuario) {
      return res.status(404).json({ mensaje: "Usuario no encontrado" });
    }

    const resumen = await ResumenReciclaje.findOne({
      usuarioId: req.usuario.id
    }).lean();

    const ventas = await VentaReciclaje.find({
      usuarioId: req.usuario.id
    })
      .sort({ fecha: -1 })
      .limit(10)
      .lean();

    return res.json({
      resumen: {
        kilosTotales: resumen?.kilosTotales ?? 0,
        dineroGanado: resumen?.dineroGanadoTotal ?? 0,
        puntosEco: resumen?.puntosEcoTotales ?? 0
      },
      ventas: ventas.map((venta) => ({
        id: venta._id,
        usuarioId: venta.usuarioId,
        puntoCompraId: venta.puntoCompraId,
        puntoCompraNombre: venta.puntoCompraNombre,
        qrCodigo: venta.qrCodigo,
        materiales: venta.materiales,
        kilos: venta.kilos,
        valorGanado: venta.dineroGanado,
        puntosGanados: venta.puntosGanados,
        fecha: venta.fecha
      }))
    });
  } catch (error) {
    console.error("Error obteniendo resumen de reciclaje:", error);
    return res.status(500).json({ mensaje: "Error obteniendo el resumen" });
  }
};

export const registrarVentaReciclaje = async (req, res) => {
  try {
    const { qrContenido, kilos, valorGanado, materiales } = req.body;

    const puntoCompraId = extraerIdPuntoDesdeQr(qrContenido);
    const materialesEntrada = Array.isArray(materiales)
      ? materiales
          .map((item) => ({
            nombre: normalizarNombreMaterial(item?.nombre),
            kilos: Number(item?.kilos),
            valorGanado: Number(item?.valorGanado)
          }))
          .filter(
            (item) =>
              item.nombre &&
              Number.isFinite(item.kilos) &&
              item.kilos > 0 &&
              Number.isFinite(item.valorGanado) &&
              item.valorGanado >= 0
          )
      : [];

    const kilosNumero = materialesEntrada.length > 0
      ? materialesEntrada.reduce((sum, item) => sum + item.kilos, 0)
      : Number(kilos);
    const valorNumero = materialesEntrada.length > 0
      ? materialesEntrada.reduce((sum, item) => sum + item.valorGanado, 0)
      : Number(valorGanado);

    if (!puntoCompraId) {
      return res.status(400).json({ mensaje: "QR invalido" });
    }

    if (!Number.isFinite(kilosNumero) || kilosNumero <= 0) {
      return res.status(400).json({ mensaje: "Los kilos deben ser mayores a 0" });
    }

    if (!Number.isFinite(valorNumero) || valorNumero < 0) {
      return res.status(400).json({ mensaje: "El valor ganado no es valido" });
    }

    if (materialesEntrada.length === 0) {
      return res.status(400).json({
        mensaje: "Debes registrar al menos un material valido"
      });
    }

    const punto = await PuntoCompra.findById(puntoCompraId).lean();

    if (!punto || !punto.activo) {
      return res.status(404).json({ mensaje: "Punto de compra no encontrado" });
    }

    const usuario = await Usuario.findById(req.usuario.id);

    if (!usuario) {
      return res.status(404).json({ mensaje: "Usuario no encontrado" });
    }

    const nombresMateriales = [...new Set(materialesEntrada.map((item) => item.nombre))];
    const materialesPuntaje = await MaterialPuntaje.find({
      material: { $in: nombresMateriales },
      activo: true
    }).lean();

    const puntajePorMaterial = new Map(
      materialesPuntaje.map((item) => [item.material.toLowerCase(), item.puntosPorKilo])
    );

    const materialesSinConfigurar = materialesEntrada.filter(
      (item) => !puntajePorMaterial.has(item.nombre.toLowerCase())
    );

    if (materialesSinConfigurar.length > 0) {
      return res.status(400).json({
        mensaje: `Estos materiales no tienen puntaje configurado: ${materialesSinConfigurar.map((item) => item.nombre).join(", ")}`
      });
    }

    const materialesNormalizados = materialesEntrada.map((item) => {
      const puntosPorKilo = puntajePorMaterial.get(item.nombre.toLowerCase()) ?? 0;
      const puntosGanados = Math.max(1, Math.round(item.kilos * puntosPorKilo));

      return {
        ...item,
        puntosPorKilo,
        puntosGanados
      };
    });

    const puntosGanados = materialesNormalizados.reduce(
      (sum, item) => sum + item.puntosGanados,
      0
    );

    const venta = await VentaReciclaje.create({
      usuarioId: usuario._id,
      puntoCompraId: punto._id,
      puntoCompraNombre: punto.nombre,
      qrCodigo: qrContenido,
      materiales: materialesNormalizados,
      kilos: kilosNumero,
      dineroGanado: valorNumero,
      puntosGanados
    });

    const resumen = await ResumenReciclaje.findOneAndUpdate(
      { usuarioId: usuario._id },
      {
        $inc: {
          kilosTotales: kilosNumero,
          dineroGanadoTotal: valorNumero,
          puntosEcoTotales: puntosGanados
        },
        $set: {
          ultimaActualizacion: new Date()
        }
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true
      }
    ).lean();

    return res.status(201).json({
      mensaje: "Venta registrada correctamente",
      venta: {
        id: venta._id,
        usuarioId: venta.usuarioId,
        puntoCompraId: venta.puntoCompraId,
        qrCodigo: venta.qrCodigo,
        materiales: venta.materiales,
        kilos: venta.kilos,
        valorGanado: venta.dineroGanado,
        puntosGanados: venta.puntosGanados,
        fecha: venta.fecha,
        puntoCompraNombre: punto.nombre
      },
      resumen: {
        kilosTotales: resumen?.kilosTotales ?? 0,
        dineroGanado: resumen?.dineroGanadoTotal ?? 0,
        puntosEco: resumen?.puntosEcoTotales ?? 0
      }
    });
  } catch (error) {
    console.error("Error registrando venta de reciclaje:", error);
    return res.status(500).json({ mensaje: "Error registrando la venta" });
  }
};
