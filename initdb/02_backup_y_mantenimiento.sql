-- =====================================================
-- SCRIPTS DE BACKUP Y MANTENIMIENTO
-- Proyecto: Sistema de Gestión de Usuarios
-- Motor: MySQL 8.0+
-- =====================================================

-- =====================================================
-- PROCEDIMIENTOS DE MANTENIMIENTO
-- =====================================================

-- Procedimiento para limpiar usuarios inactivos antiguos
DELIMITER //
CREATE PROCEDURE sp_limpiar_usuarios_inactivos(IN dias_antiguedad INT)
BEGIN
    DECLARE cantidad_eliminados INT DEFAULT 0;
    
    -- Eliminar usuarios inactivos con más de X días de antigüedad
    DELETE FROM usuarios 
    WHERE estado = 'inactivo' 
    AND fecha_actualizacion < DATE_SUB(NOW(), INTERVAL dias_antiguedad DAY);
    
    SET cantidad_eliminados = ROW_COUNT();
    
    -- Registrar la operación
    SELECT CONCAT('Se eliminaron ', cantidad_eliminados, ' usuarios inactivos antiguos') AS mensaje;
END //
DELIMITER ;

-- Procedimiento para actualizar estadísticas
DELIMITER //
CREATE PROCEDURE sp_actualizar_estadisticas()
BEGIN
    -- Crear tabla temporal para estadísticas
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_estadisticas (
        total_usuarios INT,
        usuarios_activos INT,
        usuarios_inactivos INT,
        edad_promedio DECIMAL(5,2),
        fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    
    -- Insertar datos actuales
    INSERT INTO temp_estadisticas (total_usuarios, usuarios_activos, usuarios_inactivos, edad_promedio)
    SELECT 
        COUNT(*) as total_usuarios,
        COUNT(CASE WHEN estado = 'activo' THEN 1 END) as usuarios_activos,
        COUNT(CASE WHEN estado = 'inactivo' THEN 1 END) as usuarios_inactivos,
        AVG(edad) as edad_promedio
    FROM usuarios;
    
    -- Mostrar estadísticas
    SELECT * FROM temp_estadisticas;
END //
DELIMITER ;

-- Procedimiento para validar integridad de datos
DELIMITER //
CREATE PROCEDURE sp_validar_integridad()
BEGIN
    -- Verificar emails duplicados (no debería haber por la constraint UNIQUE)
    SELECT 
        email,
        COUNT(*) as cantidad_duplicados
    FROM usuarios
    GROUP BY email
    HAVING COUNT(*) > 1;
    
    -- Verificar usuarios con edad inválida
    SELECT 
        id,
        nombre,
        email,
        edad
    FROM usuarios
    WHERE edad IS NOT NULL 
    AND (edad < 0 OR edad > 150);
    
    -- Verificar usuarios sin email
    SELECT 
        id,
        nombre
    FROM usuarios
    WHERE email IS NULL OR email = '';
END //
DELIMITER ;

-- =====================================================
-- FUNCIONES ÚTILES
-- =====================================================

-- Función para calcular edad a partir de fecha de nacimiento (futura implementación)
DELIMITER //
CREATE FUNCTION fn_calcular_edad(fecha_nacimiento DATE) 
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE edad INT;
    
    SET edad = TIMESTAMPDIFF(YEAR, fecha_nacimiento, CURDATE());
    
    RETURN edad;
END //
DELIMITER ;

-- Función para formatear nombre completo
DELIMITER //
CREATE FUNCTION fn_formatear_nombre(nombre VARCHAR(100)) 
RETURNS VARCHAR(100)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE nombre_formateado VARCHAR(100);
    
    -- Convertir a formato título (primera letra mayúscula)
    SET nombre_formateado = UPPER(LEFT(nombre, 1)) + LOWER(SUBSTRING(nombre, 2));
    
    RETURN nombre_formateado;
END //
DELIMITER ;

-- =====================================================
-- TRIGGERS PARA AUDITORÍA
-- =====================================================

-- Trigger para registrar cambios en usuarios
DELIMITER //
CREATE TRIGGER trg_usuarios_audit_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
    -- Aquí se podría insertar en una tabla de auditoría
    -- Ejemplo: INSERT INTO auditoria_usuarios (accion, usuario_id, datos_antiguos, datos_nuevos, fecha) 
    -- VALUES ('INSERT', NEW.id, NULL, JSON_OBJECT('nombre', NEW.nombre, 'email', NEW.email), NOW());
    
    -- Por ahora, solo un log simple
    SELECT CONCAT('Nuevo usuario creado: ', NEW.nombre, ' (ID: ', NEW.id, ')') AS mensaje;
END //
DELIMITER ;

-- Trigger para actualizar timestamp de modificación
DELIMITER //
CREATE TRIGGER trg_usuarios_audit_update
BEFORE UPDATE ON usuarios
FOR EACH ROW
BEGIN
    -- El timestamp de actualización se maneja automáticamente con DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    -- Pero aquí podríamos agregar lógica adicional de auditoría
    
    -- Ejemplo: registrar cambios significativos
    IF OLD.nombre != NEW.nombre OR OLD.email != NEW.email OR OLD.estado != NEW.estado THEN
        -- Aquí se podría registrar en tabla de auditoría
        SELECT CONCAT('Usuario modificado: ', NEW.nombre, ' (ID: ', NEW.id, ')') AS mensaje;
    END IF;
END //
DELIMITER ;

-- =====================================================
-- COMANDOS DE BACKUP
-- =====================================================

-- NOTA: Estos son comandos que deben ejecutarse desde la línea de comandos, no desde MySQL

-- Backup completo de la base de datos
-- mysqldump -u root -p --single-transaction --routines --triggers proyecto_db > backup_completo_$(date +%Y%m%d_%H%M%S).sql

-- Backup solo de datos (sin estructura)
-- mysqldump -u root -p --no-create-info --single-transaction proyecto_db > backup_datos_$(date +%Y%m%d_%H%M%S).sql

-- Backup solo de estructura (sin datos)
-- mysqldump -u root -p --no-data --routines --triggers proyecto_db > backup_estructura_$(date +%Y%m%d_%H%M%S).sql

-- Backup de tabla específica
-- mysqldump -u root -p --single-transaction proyecto_db usuarios > backup_usuarios_$(date +%Y%m%d_%H%M%S).sql

-- =====================================================
-- COMANDOS DE RESTAURACIÓN
-- =====================================================

-- NOTA: Estos son comandos que deben ejecutarse desde la línea de comandos

-- Restaurar backup completo
-- mysql -u root -p proyecto_db < backup_completo_20240430_120000.sql

-- Restaurar solo datos
-- mysql -u root -p proyecto_db < backup_datos_20240430_120000.sql

-- =====================================================
-- CONSULTAS DE MONITOREO Y DIAGNÓSTICO
-- =====================================================

-- Ver tamaño de la base de datos
SELECT 
    table_schema as 'Base de Datos',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Tamaño (MB)'
FROM information_schema.tables
WHERE table_schema = 'proyecto_db'
GROUP BY table_schema;

-- Ver tamaño de tablas individuales
SELECT 
    table_name as 'Tabla',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Tamaño (MB)'
FROM information_schema.tables
WHERE table_schema = 'proyecto_db'
ORDER BY (data_length + index_length) DESC;

-- Ver usuarios por estado
SELECT 
    estado,
    COUNT(*) as cantidad,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM usuarios), 2) as porcentaje
FROM usuarios
GROUP BY estado;

-- Ver distribución de edades
SELECT 
    CASE 
        WHEN edad IS NULL THEN 'No especificada'
        WHEN edad < 18 THEN 'Menor de 18'
        WHEN edad BETWEEN 18 AND 25 THEN '18-25 años'
        WHEN edad BETWEEN 26 AND 35 THEN '26-35 años'
        WHEN edad BETWEEN 36 AND 50 THEN '36-50 años'
        ELSE 'Mayor de 50'
    END as rango_edad,
    COUNT(*) as cantidad
FROM usuarios
GROUP BY 
    CASE 
        WHEN edad IS NULL THEN 'No especificada'
        WHEN edad < 18 THEN 'Menor de 18'
        WHEN edad BETWEEN 18 AND 25 THEN '18-25 años'
        WHEN edad BETWEEN 26 AND 35 THEN '26-35 años'
        WHEN edad BETWEEN 36 AND 50 THEN '36-50 años'
        ELSE 'Mayor de 50'
    END
ORDER BY cantidad DESC;

-- =====================================================
-- SCRIPTS DE LIMPIEZA Y OPTIMIZACIÓN
-- =====================================================

-- Optimizar tablas (ejecutar periódicamente)
-- OPTIMIZE TABLE usuarios;

-- Analizar tablas para actualizar estadísticas del optimizador
-- ANALYZE TABLE usuarios;

-- Verificar integridad de la tabla
-- CHECK TABLE usuarios;

-- Reparar tabla si es necesario
-- REPAIR TABLE usuarios;

-- =====================================================
-- COMENTARIOS FINALES
-- =====================================================

-- Este script proporciona herramientas para:
-- 1. Mantenimiento periódico de la base de datos
-- 2. Backup y restauración
-- 3. Monitoreo y diagnóstico
-- 4. Auditoría de cambios
-- 5. Optimización del rendimiento

-- Recomendaciones de ejecución:
-- - Ejecutar sp_actualizar_estadisticas() semanalmente
-- - Ejecutar sp_limpiar_usuarios_inactivos(90) mensualmente
-- - Realizar backups completos diariamente
-- - Monitorear el tamaño de la base de datos semanalmente
