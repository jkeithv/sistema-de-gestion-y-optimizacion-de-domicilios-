-- 005_crear_detalle_pedido.sql
-- R04: resuelve la relacion N:M entre pedido y producto.
CREATE TABLE detalle_pedido (
    id_pedido        INTEGER NOT NULL,
    id_producto      INTEGER NOT NULL,
    cantidad         INTEGER NOT NULL,
    precio_unitario  DECIMAL(12,2) NOT NULL,   -- precio historico al momento del pedido
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto),
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
        REFERENCES producto (id_producto) ON DELETE RESTRICT,
    CONSTRAINT ck_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT ck_detalle_precio   CHECK (precio_unitario >= 0)
);
