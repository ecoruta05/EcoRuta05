from contextlib import asynccontextmanager
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from datetime import datetime
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path
from loguru import logger
import uuid

# Importar clasificadores
from classifier.core import ClasificadorAvanzado
from vision.clasificador_vision import ClasificadorVision

# ============ CONFIGURACIÓN DE LA APLICACIÓN ============

# Directorios
UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)
DB_PATH = "storage/clasificaciones.db"

# Instancias globales de los clasificadores (se inicializarán en el lifespan)
clasificador_texto = None
clasificador_vision = None

# ============ MANEJADOR DE CICLO DE VIDA (LIFESPAN) ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Código que se ejecuta al iniciar y apagar la aplicación.
    Reemplaza los eventos startup y shutdown deprecados.
    """
    # --- STARTUP (se ejecuta ANTES de que la app reciba peticiones) ---
    global clasificador_texto, clasificador_vision
    logger.info("🚀 Iniciando aplicación EcoRuta IA...")
    
    # Inicializar base de datos
    init_db()
    
    # Cargar los modelos de IA (esto es lo pesado que se hace una sola vez)
    clasificador_texto = ClasificadorAvanzado()
    clasificador_vision = ClasificadorVision()
    logger.info("✅ Modelos de IA cargados correctamente")
    
    yield  # <--- Aquí la aplicación se ejecuta y atiende peticiones
    
    # --- SHUTDOWN (se ejecuta DESPUÉS de que la app se apaga) ---
    logger.info("🛑 Apagando aplicación EcoRuta IA...")
    # Aquí podrías agregar código de limpieza (ej: cerrar conexiones a bases de datos)

# ============ INICIALIZACIÓN DE LA BASE DE DATOS ============

@contextmanager
def get_db():
    os.makedirs("storage", exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()

def init_db():
    """Crea las tablas necesarias si no existen"""
    with get_db() as db:
        db.execute('''
            CREATE TABLE IF NOT EXISTS clasificaciones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                tipo TEXT,
                objeto TEXT,
                categoria TEXT,
                accion TEXT,
                confianza REAL,
                timestamp TEXT
            )
        ''')
    logger.info("📦 Base de datos inicializada")

# ============ APLICACIÓN FASTAPI ============

app = FastAPI(
    title="EcoRuta - IA Visión",
    version="2.0.0",
    lifespan=lifespan  # <--- Usamos el nuevo sistema lifespan
)

# Configuración CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, especifica los dominios permitidos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============ ENDPOINTS ============

@app.get("/")
def root():
    return {
        "servicio": "EcoRuta - IA Visión",
        "version": "2.0.0",
        "status": "activo"
    }

@app.get("/health")
def health():
    vision_status = "ready"
    if clasificador_vision is None:
        vision_status = "not_initialized"
    elif not getattr(clasificador_vision, "_modelo_disponible", False):
        vision_status = "model_unavailable"

    return {
        "status": "healthy",
        "vision_status": vision_status,
        "timestamp": datetime.now().isoformat(),
    }

@app.post("/clasificar/texto")
async def clasificar_texto(
    nombre: str,
    material: Optional[str] = None,
    estado: Optional[str] = None,
    electronico: bool = False,
    contiene_baterias: bool = False
):
    # Verificar que el clasificador esté disponible (seguridad)
    if clasificador_texto is None:
        raise HTTPException(503, "Servicio de IA no inicializado aún")
    
    resultado = clasificador_texto.clasificar(
        nombre=nombre,
        material=material,
        estado=estado,
        electronico=electronico,
        contiene_baterias=contiene_baterias
    )
    
    # Guardar en base de datos
    with get_db() as db:
        db.execute(
            "INSERT INTO clasificaciones (tipo, objeto, categoria, accion, confianza, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
            ("texto", nombre, resultado["categoria"].value, resultado["accion"].value, 
             resultado["confianza"], datetime.now().isoformat())
        )
    
    return {
        "exito": True,
        "metodo": "texto",
        "objeto": nombre,
        "categoria": resultado["categoria"].value,
        "accion": resultado["accion"].value,
        "confianza": resultado["confianza"],
        "instrucciones": resultado["instrucciones"],
        "factores": resultado["factores"],
        "timestamp": datetime.now().isoformat()
    }

@app.post("/clasificar/imagen")
async def clasificar_imagen(file: UploadFile = File(...)):
    content_type = (file.content_type or "").lower()
    filename = (file.filename or "").lower()
    extensiones_validas = (".jpg", ".jpeg", ".png", ".webp", ".bmp")
    es_imagen = content_type.startswith("image/") or filename.endswith(extensiones_validas)

    if not es_imagen:
        raise HTTPException(
            400,
            f"El archivo debe ser una imagen. content_type={file.content_type}, filename={file.filename}",
        )
    
    if clasificador_vision is None:
        raise HTTPException(503, "Servicio de IA no inicializado aún")
    
    imagen_bytes = await file.read()
    try:
        resultado = clasificador_vision.clasificar_desde_imagen(imagen_bytes)
    except Exception as e:
        logger.exception(f"Error clasificando imagen {file.filename}: {e}")
        raise HTTPException(500, "No fue posible procesar la imagen")
    
    # Guardar en base de datos
    with get_db() as db:
        db.execute(
            "INSERT INTO clasificaciones (tipo, objeto, categoria, accion, confianza, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
            ("imagen", resultado.get("objeto_detectado", "desconocido"), 
             resultado.get("categoria", "reciclable"), resultado.get("accion", "reciclar"),
             resultado.get("confianza", 0.5), datetime.now().isoformat())
        )
    
    return {
        "exito": True,
        "metodo": "vision",
        "resultado": resultado,
        "timestamp": datetime.now().isoformat()
    }

@app.get("/historial")
async def get_historial(limite: int = 50):
    with get_db() as db:
        rows = db.execute(
            "SELECT * FROM clasificaciones ORDER BY timestamp DESC LIMIT ?",
            (limite,)
        ).fetchall()
        return [dict(row) for row in rows]

@app.get("/estadisticas")
async def get_estadisticas():
    with get_db() as db:
        total = db.execute("SELECT COUNT(*) as total FROM clasificaciones").fetchone()["total"]
        por_categoria = db.execute("""
            SELECT categoria, COUNT(*) as count 
            FROM clasificaciones 
            GROUP BY categoria
        """).fetchall()
    
    return {
        "total_clasificaciones": total,
        "por_categoria": [{"categoria": row["categoria"], "count": row["count"]} for row in por_categoria]
    }

# ============ EJECUCIÓN DIRECTA (SIN UVICORN) ============

if __name__ == "__main__":
    import uvicorn
    print("=" * 50)
    print("🚀 EcoRuta - Servicio IA (Modo Moderno)")
    print("=" * 50)
    print(f"📁 Uploads: {UPLOAD_DIR.absolute()}")
    print(f"💾 Base de datos: {DB_PATH}")
    print("🌐 Servidor: http://0.0.0.0:8000")
    print("📚 Documentación: http://localhost:8000/docs")
    print("✨ Usando lifespan events (reemplaza on_event)")
    print("=" * 50)
    # El servidor se ejecuta correctamente y se mantiene abierto
    uvicorn.run(app, host="0.0.0.0", port=8000)
