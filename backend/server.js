import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import { conectarDB } from "./config/db.js";
import authRoutes from "./routes/auth.routes.js";
import puntoCompraRoutes from "./routes/puntoCompra.routes.js";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

app.use("/api/auth", authRoutes);
app.use("/api/puntos-compra", puntoCompraRoutes);

app.get("/", (req, res) => {
  res.send("Servidor funcionando 🚀");
});

const iniciarServidor = async () => {
  try {
    await conectarDB();

    const PORT = process.env.PORT || 3000;

    app.listen(PORT, () => {
      console.log("🚀 Servidor en puerto", PORT);
    });
    
  } catch (error) {
    console.error("❌ Error al iniciar el servidor:", error.message);
    process.exit(1);
  }
};

iniciarServidor();
