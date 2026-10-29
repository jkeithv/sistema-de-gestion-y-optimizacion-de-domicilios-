-- 01_indice_ubicacion.sql
-- Caso de índice: historial del recorrido de un servicio (requisitos R09 y R11).
-- Uso (desde la raíz del repositorio, sobre la base ya migrada y con datos):
--   psql -d domicilios -f docs/evidencia/01_indice_ubicacion.sql
-- Es repetible: borra el índice del caso antes de medir el "antes".

\set ON_ERROR_STOP on
\timing on

-- Dejar el índice del caso fuera para medir el "antes".
-- Si 010_indices.sql ya se aplicó, este DROP no lo borra de forma permanente:
-- el índice se vuelve a crear al final.
DROP INDEX IF EXISTS idx_ubicacion_servicio_fecha;
ANALYZE ubicacion;

-- Datos del volumen disponible
SELECT count(*) AS filas_ubicacion FROM ubicacion;
SELECT count(DISTINCT idServicio) AS servicios_con_ubicacion FROM ubicacion;

-- Elegir un servicio con muchas posiciones (se usa en las dos mediciones)
SELECT idServicio AS servicio_prueba
FROM ubicacion
GROUP BY idServicio
ORDER BY count(*) DESC, idServicio
LIMIT 1 \gset

\echo '=== CONSULTA ==='
\echo 'Recorrido del servicio :servicio_prueba, en orden cronológico'

\echo '=== PLAN ANTES (sin índice) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT idUbicacion, fechaHora, latitud, longitud
FROM ubicacion
WHERE idServicio = :servicio_prueba
ORDER BY fechaHora;

CREATE INDEX idx_ubicacion_servicio_fecha ON ubicacion (idServicio, fechaHora);
ANALYZE ubicacion;

\echo '=== PLAN DESPUÉS (con índice) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT idUbicacion, fechaHora, latitud, longitud
FROM ubicacion
WHERE idServicio = :servicio_prueba
ORDER BY fechaHora;
