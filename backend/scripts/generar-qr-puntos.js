import dotenv from "dotenv";
import fs from "fs/promises";
import path from "path";
import QRCode from "qrcode";
import { conectarDB } from "../config/db.js";
import PuntoCompra from "../models/puntoCompra.js";

dotenv.config();

const ejecutar = async () => {
  try {
    await conectarDB();

    const puntos = await PuntoCompra.find({ activo: true })
      .sort({ nombre: 1 })
      .lean();

    const outputDir = path.resolve("qr-puntos-compra");
    await fs.mkdir(outputDir, { recursive: true });

    const qrPuntos = puntos.map((punto) => ({
      nombre: punto.nombre,
      archivoBase: `${punto.nombre.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`,
      contenidoQr: JSON.stringify({
        tipo: "punto_compra",
        puntoCompraId: punto._id.toString(),
        nombre: punto.nombre
      })
    }));

    for (const qr of qrPuntos) {
      const rutaPng = path.join(outputDir, `${qr.archivoBase}.png`);

      await QRCode.toFile(rutaPng, qr.contenidoQr, {
        type: "png",
        width: 400,
        margin: 2
      });
    }

    console.log(JSON.stringify(qrPuntos, null, 2));
    console.log(`QR generados en: ${outputDir}`);
    process.exit(0);
  } catch (error) {
    console.error("Error generando QR de puntos:", error);
    process.exit(1);
  }
};

ejecutar();
