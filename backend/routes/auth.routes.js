import express from "express";
import { registro, checkEmail } from "../controllers/registro.controller.js";
import { login, cambiarPassword } from "../controllers/login.controller.js";
import { verificarToken } from "../middleware/auth.middleware.js";

const router = express.Router();

router.get("/check-email/:correo", checkEmail);
router.post("/registro", registro);
router.post("/login", login);
router.put("/cambiar-password", verificarToken, cambiarPassword);
router.post("/cambiar-password", verificarToken, cambiarPassword);

export default router;