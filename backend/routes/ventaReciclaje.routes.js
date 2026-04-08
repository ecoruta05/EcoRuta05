import express from "express";
import {
  obtenerResumenReciclaje,
  registrarVentaReciclaje
} from "../controllers/ventaReciclaje.controller.js";
import { verificarToken } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/resumen", verificarToken, obtenerResumenReciclaje);
router.post("/registrar", verificarToken, registrarVentaReciclaje);

export default router;
