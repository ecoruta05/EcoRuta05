export const puntosCompraSeed = [
  {
    nombre: "ReciMeta Centro",
    ciudad: "Villavicencio",
    barrio: "Centro",
    direccion: "Calle 38 # 30-58, Villavicencio, Meta",
    referencia: "A una cuadra del Parque Los Libertadores",
    horario: "Lunes a sabado, 8:00 a. m. - 5:30 p. m.",
    telefono: "3204567812",
    descripcion:
      "Compra materiales reciclables separados y limpios. Recibe volumen pequeno y mediano.",
    materialesCompra: ["Plastico", "Carton", "Papel archivo", "Aluminio", "Chatarra liviana"],
    activo: true,
    ubicacion: {
      type: "Point",
      coordinates: [-73.6372, 4.1495],
    },
  },
  {
    nombre: "EcoCompra Barzal",
    ciudad: "Villavicencio",
    barrio: "Barzal",
    direccion: "Carrera 33 # 41-16, Villavicencio, Meta",
    referencia: "Frente a zona comercial del Barzal alto",
    horario: "Lunes a viernes, 7:30 a. m. - 5:00 p. m.",
    telefono: "3139021456",
    descripcion:
      "Punto de compra enfocado en plastico PET, carton y metales no ferrosos.",
    materialesCompra: ["PET", "Plastico duro", "Carton", "Cobre", "Aluminio"],
    activo: true,
    ubicacion: {
      type: "Point",
      coordinates: [-73.6311, 4.1534],
    },
  },
  {
    nombre: "Acopio Catama Verde",
    ciudad: "Villavicencio",
    barrio: "Catama",
    direccion: "Avenida Catama # 22-40, Villavicencio, Meta",
    referencia: "Cerca del cruce principal de la Avenida Catama",
    horario: "Lunes a sabado, 8:00 a. m. - 4:30 p. m.",
    telefono: "3147782301",
    descripcion:
      "Recibe carton, archivo, vidrio clasificado y envases Tetra Pak.",
    materialesCompra: ["Carton", "Papel", "Vidrio", "Tetra Pak"],
    activo: true,
    ubicacion: {
      type: "Point",
      coordinates: [-73.6159, 4.1346],
    },
  },
  {
    nombre: "Punto de Compra San Benito",
    ciudad: "Villavicencio",
    barrio: "San Benito",
    direccion: "Carrera 24 # 18-33, Villavicencio, Meta",
    referencia: "Sobre via secundaria de acceso al barrio",
    horario: "Lunes a viernes, 8:00 a. m. - 6:00 p. m.",
    telefono: "3156409824",
    descripcion:
      "Compra chatarra, aluminio, hierro y algunos residuos aprovechables industriales.",
    materialesCompra: ["Hierro", "Acero", "Aluminio", "Chatarra", "Cables"],
    activo: true,
    ubicacion: {
      type: "Point",
      coordinates: [-73.6268, 4.1428],
    },
  },
  {
    nombre: "Ruta Circular La Esperanza",
    ciudad: "Villavicencio",
    barrio: "La Esperanza",
    direccion: "Calle 25 # 39-20, Villavicencio, Meta",
    referencia: "Esquina con supermercado del sector",
    horario: "Todos los dias, 9:00 a. m. - 6:30 p. m.",
    telefono: "3225176048",
    descripcion:
      "Compra materiales domesticos reciclables previamente separados y secos.",
    materialesCompra: ["Plastico", "Carton", "Papel", "Latas", "Vidrio"],
    activo: true,
    ubicacion: {
      type: "Point",
      coordinates: [-73.6237, 4.1471],
    },
  },
];
