-- =====================================================
-- SCRIPT DE CREACIÓN DE BASE DE DATOS
-- Proyecto: Sistema de Gestión de Usuarios
-- Motor: MySQL 8.0+
-- Autor: Sistema de Desarrollo
-- Fecha: 2024
-- =====================================================

-- Eliminar base de datos si existe (para desarrollo)
-- ADVERTENCIA: Esto eliminará todos los datos existentes
-- DROP DATABASE IF EXISTS proyecto_db;

-- Crear base de datos principal
CREATE DATABASE IF NOT EXISTS proyecto_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- Seleccionar la base de datos para uso
USE proyecto_db;

-- =====================================================
-- TABLA: usuarios
-- Almacena información básica de los usuarios del sistema
-- =====================================================

CREATE TABLE IF NOT EXISTS usuarios (
    -- ID único para cada usuario (clave primaria)
    id INT AUTO_INCREMENT PRIMARY KEY,
    
    -- Nombre completo del usuario (obligatorio)
    nombre VARCHAR(100) NOT NULL COMMENT 'Nombre completo del usuario',
    
    -- Correo electrónico único (obligatorio)
    email VARCHAR(150) NOT NULL UNIQUE COMMENT 'Correo electrónico único del usuario',
    
    -- Edad del usuario (opcional)
    edad INT NULL COMMENT 'Edad del usuario (opcional)',
    
    -- Fecha de creación del registro (automática)
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Fecha y hora de creación del registro',
    
    -- Fecha de última actualización (automática)
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Fecha y hora de última actualización',
    
    -- Estado del usuario (activo/inactivo)
    estado ENUM('activo', 'inactivo') DEFAULT 'activo' COMMENT 'Estado actual del usuario'
) ENGINE=InnoDB COMMENT 'Tabla principal de usuarios del sistema';

-- =====================================================
-- ÍNDICES para optimización de consultas
-- =====================================================

-- Índice para búsquedas por email (ya es único por la constraint)
-- MySQL crea automáticamente un índice para columnas UNIQUE

-- Índice para búsquedas por nombre
CREATE INDEX idx_usuarios_nombre ON usuarios(nombre);

-- Índice para búsquedas por estado
CREATE INDEX idx_usuarios_estado ON usuarios(estado);

-- Índice para búsquedas por fecha de creación
CREATE INDEX idx_usuarios_fecha_creacion ON usuarios(fecha_creacion);

-- Índice compuesto para consultas frecuentes
CREATE INDEX idx_usuarios_nombre_estado ON usuarios(nombre, estado);

-- =====================================================
-- INSERCIÓN DE DATOS DE EJEMPLO (opcional)
-- =====================================================

-- Insertar usuarios de ejemplo para pruebas iniciales
INSERT INTO usuarios (nombre, email, edad, estado) VALUES
('Juan Pérez García', 'juan.perez@ejemplo.com', 28, 'activo'),
('María Rodríguez López', 'maria.rodriguez@ejemplo.com', 34, 'activo'),
('Carlos Martínez Sánchez', 'carlos.martinez@ejemplo.com', 45, 'activo'),
('Ana González Fernández', 'ana.gonzalez@ejemplo.com', 22, 'activo'),
('Luis Hernández Torres', 'luis.hernandez@ejemplo.com', 39, 'inactivo'),
('Sofía Díaz Ramírez', 'sofia.diaz@ejemplo.com', 31, 'activo'),
('Pedro Jiménez Castro', 'pedro.jimenez@ejemplo.com', 27, 'activo'),
('Laura Moreno Vargas', 'laura.moreno@ejemplo.com', 29, 'activo')
ON DUPLICATE KEY UPDATE 
    nombre = VALUES(nombre),
    edad = VALUES(edad),
    estado = VALUES(estado);

-- =====================================================
-- VISTAS ÚTILES (opcional)
-- =====================================================

-- Vista para usuarios activos
CREATE OR REPLACE VIEW vista_usuarios_activos AS
SELECT 
    id,
    nombre,
    email,
    edad,
    fecha_creacion,
    fecha_actualizacion
FROM usuarios 
WHERE estado = 'activo';

-- Vista para estadísticas básicas
CREATE OR REPLACE VIEW vista_estadisticas_usuarios AS
SELECT 
    COUNT(*) as total_usuarios,
    COUNT(CASE WHEN estado = 'activo' THEN 1 END) as usuarios_activos,
    COUNT(CASE WHEN estado = 'inactivo' THEN 1 END) as usuarios_inactivos,
    AVG(edad) as edad_promedio,
    MIN(edad) as edad_minima,
    MAX(edad) as edad_maxima,
    DATE(fecha_creacion) as fecha_registro
FROM usuarios
GROUP BY DATE(fecha_creacion);

-- =====================================================
-- PROCEDIMIENTOS ALMACENADOS (opcional)
-- =====================================================

-- Procedimiento para obtener usuario por ID
DELIMITER //
CREATE PROCEDURE sp_obtener_usuario_por_id(IN p_id INT)
BEGIN
    SELECT 
        id,
        nombre,
        email,
        edad,
        estado,
        fecha_creacion,
        fecha_actualizacion
    FROM usuarios
    WHERE id = p_id;
END //
DELIMITER ;

-- Procedimiento para crear usuario
DELIMITER //
CREATE PROCEDURE sp_crear_usuario(
    IN p_nombre VARCHAR(100),
    IN p_email VARCHAR(150),
    IN p_edad INT,
    IN p_estado VARCHAR(10)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    START TRANSACTION;
    
    INSERT INTO usuarios (nombre, email, edad, estado)
    VALUES (p_nombre, p_email, p_edad, p_estado);
    
    SELECT LAST_INSERT_ID() as usuario_id;
    
    COMMIT;
END //
DELIMITER ;

-- =====================================================
-- COMENTARIOS FINALES
-- =====================================================

-- Este script crea la estructura básica necesaria para el proyecto
-- Incluye: tabla principal, índices, datos de ejemplo, vistas y procedimientos
-- Compatible con MySQL 8.0 y versiones superiores

-- Para ejecutar este script:
-- mysql -u root -p < 01_creacion_base_datos.sql

-- Para verificar la creación:
-- USE proyecto_db;
-- SHOW TABLES;
-- DESCRIBE usuarios;
