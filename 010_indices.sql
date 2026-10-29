-- 010_indices.sql
-- PostgreSQL no crea índices automáticamente sobre las claves foráneas.
-- Se indexan las columnas FK usadas en reuniones frecuentes.
-- Renombrar el archivo con el siguiente número consecutivo si 010 ya está ocupado.
-- Los nombres de columna siguen la Entrega 1; adaptarlos si el DDL final usa otro estilo.

-- Claves foráneas
CREATE INDEX IF NOT EXISTS idx_direccion_cliente      ON direccion (idCliente);
CREATE INDEX IF NOT EXISTS idx_pedido_cliente         ON pedido (idCliente);
CREATE INDEX IF NOT EXISTS idx_pedido_direccion       ON pedido (idDireccion);
CREATE INDEX IF NOT EXISTS idx_detalle_producto       ON detalle_pedido (idProductoFK);
CREATE INDEX IF NOT EXISTS idx_empleado_central       ON empleado_central (idCentral);
CREATE INDEX IF NOT EXISTS idx_servicio_empleado      ON servicio_domicilio (idEmpleado);
CREATE INDEX IF NOT EXISTS idx_servicio_domiciliario  ON servicio_domicilio (idDomiciliario);
CREATE INDEX IF NOT EXISTS idx_vehiculo_domiciliario  ON vehiculo (idDomiciliario);
CREATE INDEX IF NOT EXISTS idx_ruta_servicio          ON ruta (idServicio);

-- detalle_pedido.idPedidoFK no necesita índice propio: es la primera columna de la PK compuesta.
-- servicio_domicilio.idPedido no lo necesita: ya tiene índice por la restricción UNIQUE.

-- Caso medido con EXPLAIN ANALYZE (ver docs/evidencia/01_indice_ubicacion.sql):
-- historial del recorrido de un servicio, ordenado por tiempo.
CREATE INDEX IF NOT EXISTS idx_ubicacion_servicio_fecha
    ON ubicacion (idServicio, fechaHora);

-- Última posición conocida de cada domiciliario (consulta de la central, R12).
CREATE INDEX IF NOT EXISTS idx_ubicacion_domiciliario_fecha
    ON ubicacion (idDomiciliario, fechaHora DESC);
