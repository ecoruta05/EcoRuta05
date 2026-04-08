import dotenv from "dotenv";
import { conectarDB } from "../config/db.js";
import { materialesPuntajeSeed } from "../data/materiales-puntaje.seed.js";
import MaterialPuntaje from "../models/materialPuntaje.js";

dotenv.config();

const ejecutar = async () => {
  try {
    await conectarDB();

    for (const material of materialesPuntajeSeed) {
      await MaterialPuntaje.findOneAndUpdate(
        { material: material.material },
        {
          ...material,
          fechaActualizacion: new Date()
        },
        {
          upsert: true,
          new: true,
          setDefaultsOnInsert: true
        }
      );
    }

    console.log(
      `Seed completado: ${materialesPuntajeSeed.length} materiales de puntaje actualizados`
    );
    process.exit(0);
  } catch (error) {
    console.error("Error ejecutando seed de materiales_puntaje:", error);
    process.exit(1);
  }
};

ejecutar();
