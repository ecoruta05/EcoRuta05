import mongoose from "mongoose";

const resumenReciclajeSchema = new mongoose.Schema(
  {
    usuarioId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Usuario",
      required: true,
      unique: true,
      index: true
    },
    kilosTotales: {
      type: Number,
      default: 0
    },
    dineroGanadoTotal: {
      type: Number,
      default: 0
    },
    puntosEcoTotales: {
      type: Number,
      default: 0
    },
    ultimaActualizacion: {
      type: Date,
      default: Date.now
    }
  },
  {
    versionKey: false,
    collection: "resumen_reciclaje"
  }
);

export default mongoose.model("ResumenReciclaje", resumenReciclajeSchema);
