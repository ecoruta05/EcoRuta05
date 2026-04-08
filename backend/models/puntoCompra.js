import mongoose from "mongoose";

const puntoCompraSchema = new mongoose.Schema(
  {
    nombre: {
      type: String,
      required: true,
      trim: true,
    },
    ciudad: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    barrio: {
      type: String,
      trim: true,
      default: "",
    },
    direccion: {
      type: String,
      required: true,
      trim: true,
    },
    referencia: {
      type: String,
      trim: true,
      default: "",
    },
    horario: {
      type: String,
      required: true,
      trim: true,
    },
    telefono: {
      type: String,
      trim: true,
      default: "",
    },
    descripcion: {
      type: String,
      trim: true,
      default: "",
    },
    materialesCompra: {
      type: [String],
      required: true,
      default: [],
    },
    activo: {
      type: Boolean,
      default: true,
      index: true,
    },
    ubicacion: {
      type: {
        type: String,
        enum: ["Point"],
        required: true,
        default: "Point",
      },
      coordinates: {
        type: [Number],
        required: true,
        validate: {
          validator: (value) => Array.isArray(value) && value.length === 2,
          message: "La ubicacion debe contener [lng, lat]",
        },
      },
    },
  },
  {
    timestamps: true,
    versionKey: false,
    collection: "puntos_compra",
  }
);

puntoCompraSchema.index({ ubicacion: "2dsphere" });

export default mongoose.model("PuntoCompra", puntoCompraSchema);
