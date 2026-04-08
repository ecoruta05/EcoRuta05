import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import ResumenReciclaje from "../models/resumenReciclaje.js";
import Usuario from "../models/user.js";

export const login = async (req, res) => {
  try {
    const { correo, password } = req.body;

    const user = await Usuario.findOne({ correo });

    if (!user) {
      return res.status(404).json({ mensaje: "Usuario no encontrado" });
    }

    const valido = await bcrypt.compare(password, user.password);

    if (!valido) {
      return res.status(401).json({ mensaje: "Contraseña incorrecta" });
    }

    const token = jwt.sign(
      { id: user._id, correo: user.correo },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    const resumen = await ResumenReciclaje.findOne({
      usuarioId: user._id
    }).lean();

    res.json({
      mensaje: "Login exitoso",
      token,
      usuario: {
        id: user._id,
        nombre: user.nombre,
        correo: user.correo,
        resumenReciclaje: {
          kilosTotales: resumen?.kilosTotales ?? 0,
          dineroGanado: resumen?.dineroGanadoTotal ?? 0,
          puntosEco: resumen?.puntosEcoTotales ?? 0
        }
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ mensaje: "Error en login" });
  }
};
<<<<<<< HEAD

export const cambiarPassword = async (req, res) => {
  try {
    let { passwordActual, passwordNueva } = req.body;

    passwordActual = passwordActual || "";
    passwordNueva = passwordNueva || "";

    if (!passwordActual || !passwordNueva) {
      return res.status(400).json({
        mensaje: "Debes ingresar la contraseña actual y la nueva"
      });
    }

    if (
      passwordNueva.length < 6 ||
      !/[0-9]/.test(passwordNueva) ||
      !/[a-zA-Z]/.test(passwordNueva)
    ) {
      return res.status(400).json({
        mensaje: "La nueva contraseña debe tener minimo 6 caracteres, una letra y un numero"
      });
    }

    const user = await Usuario.findById(req.usuario.id);

    if (!user) {
      return res.status(404).json({ mensaje: "Usuario no encontrado" });
    }

    const passwordValida = await bcrypt.compare(passwordActual, user.password);

    if (!passwordValida) {
      return res.status(401).json({
        mensaje: "La contraseña actual es incorrecta"
      });
    }

    const passwordEsLaMisma = await bcrypt.compare(passwordNueva, user.password);

    if (passwordEsLaMisma) {
      return res.status(400).json({
        mensaje: "La nueva contraseña no puede ser igual a la actual"
      });
    }

    user.password = await bcrypt.hash(passwordNueva, 10);
    await user.save();

    return res.json({
      mensaje: "Contraseña actualizada correctamente"
    });
  } catch (error) {
    console.error("Error al cambiar contraseña:", error);
    return res.status(500).json({
      mensaje: "Error al cambiar contraseña"
    });
  }
};
=======
>>>>>>> 3df6d4aa30f94b91c74ca0a9a7a55d3165da4cc6
