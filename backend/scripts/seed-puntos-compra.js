import dotenv from "dotenv";
import mongoose from "mongoose";
import { puntosCompraSeed } from "../data/puntos-compra.seed.js";
import PuntoCompra from "../models/puntoCompra.js";

dotenv.config();

const run = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI);

    await PuntoCompra.deleteMany({ ciudad: "Villavicencio" });
    await PuntoCompra.insertMany(puntosCompraSeed);

    console.log(
      `Seed completado: ${puntosCompraSeed.length} puntos de compra insertados en Villavicencio`
    );
  } catch (error) {
    console.error("Error ejecutando seed de puntos_compra:", error);
    process.exitCode = 1;
  } finally {
    await mongoose.disconnect();
  }
};

run();
