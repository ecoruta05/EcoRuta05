import mongoose from "mongoose";

const ventaReciclajeSchema = new mongoose.Schema(
  {
    usuarioId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Usuario",
      required: true,
      index: true
    },
    puntoCompraId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "PuntoCompra",
      required: true,
      index: true
    },
    puntoCompraNombre: {
      type: String,
      required: true,
      trim: true
    },
    qrCodigo: {
      type: String,
      required: true,
      trim: true
    },
    materiales: {
      type: [
        {
          nombre: {
            type: String,
            required: true,
            trim: true
          },
          kilos: {
            type: Number,
            required: true,
            min: 0
          },
          valorGanado: {
            type: Number,
            required: true,
            min: 0
          },
          puntosPorKilo: {
            type: Number,
            required: true,
            min: 0
          },
          puntosGanados: {
            type: Number,
            required: true,
            min: 0
          }
        }
      ],
      default: []
    },
    kilos: {
      type: Number,
      required: true,
      min: 0
    },
    dineroGanado: {
      type: Number,
      required: true,
      min: 0
    },
    puntosGanados: {
      type: Number,
      required: true,
      min: 0
    },
    fecha: {
      type: Date,
      default: Date.now,
      index: true
    }
  },
  {
    versionKey: false,
    collection: "ventas_reciclaje"
  }
);

export default mongoose.model("VentaReciclaje", ventaReciclajeSchema);
