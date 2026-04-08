import express from "express";
import {
  listarPuntosCompra,
  obtenerPuntoCompra,
} from "../controllers/puntoCompra.controller.js";

const router = express.Router();

router.get("/", listarPuntosCompra);
router.get("/:id", obtenerPuntoCompra);

export default router;
