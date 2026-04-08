import express from "express";
import { listarMaterialesPuntaje } from "../controllers/materialPuntaje.controller.js";

const router = express.Router();

router.get("/", listarMaterialesPuntaje);

export default router;
