import mongoose from "mongoose";

const materialPuntajeSchema = new mongoose.Schema(
  {
    material: {
      type: String,
      required: true,
      unique: true,
      trim: true
    },
    puntosPorKilo: {
      type: Number,
      required: true,
      min: 0
    },
    activo: {
      type: Boolean,
      default: true,
      index: true
    },
    fechaActualizacion: {
      type: Date,
      default: Date.now
    }
  },
  {
    versionKey: false,
    collection: "materiales_puntaje"
  }
);

export default mongoose.model("MaterialPuntaje", materialPuntajeSchema);
