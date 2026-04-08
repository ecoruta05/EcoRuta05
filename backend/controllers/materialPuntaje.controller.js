import MaterialPuntaje from "../models/materialPuntaje.js";

export const listarMaterialesPuntaje = async (_req, res) => {
  try {
    const materiales = await MaterialPuntaje.find({ activo: true })
      .sort({ material: 1 })
      .lean();

    return res.json(
      materiales.map((material) => ({
        id: material._id,
        material: material.material,
        puntosPorKilo: material.puntosPorKilo
      }))
    );
  } catch (error) {
    console.error("Error listando materiales_puntaje:", error);
    return res.status(500).json({ mensaje: "Error obteniendo materiales" });
  }
};
