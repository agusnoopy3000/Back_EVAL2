// Importar dependencias necesarias
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2');
require('dotenv').config();

// Crear instancia de Express
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware para parsear JSON y permitir CORS
app.use(cors());
app.use(express.json());

// Configuración de la conexión a la base de datos MySQL
const dbConnection = mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'proyecto_db',
    port: process.env.DB_PORT || 3306,
    charset: 'utf8mb4'
});

// Conectar a la base de datos
dbConnection.connect((err) => {
    if (err) {
        console.error('Error conectando a la base de datos:', err);
        return;
    }
    console.log('Conectado exitosamente a la base de datos MySQL');
});

// Ruta de prueba para verificar que el servidor funciona
app.get('/', (req, res) => {
    res.json({ 
        message: 'API Innovatech Chile - Backend desplegado vía CI/CD',
        status: 'active',
        version: '1.1.0',
        timestamp: new Date().toISOString()
    });
});

// Rutas para usuarios
// GET - Obtener todos los usuarios
app.get('/api/usuarios', (req, res) => {
    const query = 'SELECT * FROM usuarios';
    dbConnection.query(query, (err, results) => {
        if (err) {
            console.error('Error obteniendo usuarios:', err);
            res.status(500).json({ error: 'Error al obtener usuarios' });
            return;
        }
        res.json(results.map(user => ({
  ...user,
  nombre: user.nombre ? user.nombre.slice(0, 5) : ''
})));
    });
});

// POST - Crear un nuevo usuario
app.post('/api/usuarios', (req, res) => {
    const { nombre, email, edad } = req.body;
    
    // Validar que los datos requeridos estén presentes
    if (!nombre || !email) {
        return res.status(400).json({ error: 'Nombre y email son requeridos' });
    }
    
    const query = 'INSERT INTO usuarios (nombre, email, edad) VALUES (?, ?, ?)';
    dbConnection.query(query, [nombre, email, edad || null], (err, result) => {
        if (err) {
            console.error('Error creando usuario:', err);
            res.status(500).json({ error: 'Error al crear usuario' });
            return;
        }
        res.status(201).json({
            message: 'Usuario creado exitosamente',
            id: result.insertId,
            nombre,
            email,
            edad
        });
    });
});

// PUT - Actualizar un usuario existente
app.put('/api/usuarios/:id', (req, res) => {
    const { id } = req.params;
    const { nombre, email, edad } = req.body;
    
    const query = 'UPDATE usuarios SET nombre = ?, email = ?, edad = ? WHERE id = ?';
    dbConnection.query(query, [nombre, email, edad, id], (err, result) => {
        if (err) {
            console.error('Error actualizando usuario:', err);
            res.status(500).json({ error: 'Error al actualizar usuario' });
            return;
        }
        
        if (result.affectedRows === 0) {
            res.status(404).json({ error: 'Usuario no encontrado' });
            return;
        }
        
        res.json({
            message: 'Usuario actualizado exitosamente',
            id,
            nombre,
            email,
            edad
        });
    });
});

// DELETE - Eliminar un usuario
app.delete('/api/usuarios/:id', (req, res) => {
    const { id } = req.params;
    
    const query = 'DELETE FROM usuarios WHERE id = ?';
    dbConnection.query(query, [id], (err, result) => {
        if (err) {
            console.error('Error eliminando usuario:', err);
            res.status(500).json({ error: 'Error al eliminar usuario' });
            return;
        }
        
        if (result.affectedRows === 0) {
            res.status(404).json({ error: 'Usuario no encontrado' });
            return;
        }
        
        res.json({
            message: 'Usuario eliminado exitosamente',
            id
        });
    });
});

// Manejo de rutas no encontradas
app.use('*', (req, res) => {
    res.status(404).json({ error: 'Ruta no encontrada' });
});

// Manejo de errores globales
app.use((err, req, res, next) => {
    console.error('Error no manejado:', err);
    res.status(500).json({ error: 'Error interno del servidor' });
});

// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`Servidor backend corriendo en el puerto ${PORT}`);
    console.log(`API disponible en: http://localhost:${PORT}`);
});

// Exportar la app para pruebas
module.exports = app;
