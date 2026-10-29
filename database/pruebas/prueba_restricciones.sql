-- Prueba que las restricciones RECHAZAN datos invalidos y aceptan los validos.
-- Cada caso intenta un INSERT malo; si pasa, la prueba falla.
BEGIN;

INSERT INTO cliente (nombre, telefono, correo) VALUES ('Prueba Uno','3000000001','uno@correo.test');
INSERT INTO cliente (nombre, telefono, correo) VALUES ('Prueba Dos','3000000002','dos@correo.test');
INSERT INTO direccion (id_cliente, direccion, barrio, latitud, longitud)
    SELECT id_cliente, 'Cra 5 # 10-20', 'Centro', 10.4631, -73.2532 FROM cliente WHERE correo='uno@correo.test';

CREATE TEMP TABLE resultado_pruebas (caso TEXT, ok BOOLEAN);

DO $$
DECLARE
    c1 INT; c2 INT; d1 INT;
    caso TEXT;
    casos TEXT[][] := ARRAY[
      ['correo duplicado',            $q$INSERT INTO cliente(nombre,telefono,correo) VALUES('X','1','uno@correo.test')$q$],
      ['estado de pedido invalido',   $q$INSERT INTO pedido(id_cliente,id_direccion,estado_pedido) VALUES(%1$s,%3$s,'volando')$q$],
      ['direccion de otro cliente',   $q$INSERT INTO pedido(id_cliente,id_direccion) VALUES(%2$s,%3$s)$q$],
      ['precio negativo',             $q$INSERT INTO producto(nombre,precio) VALUES('Malo',-1)$q$],
      ['latitud fuera de rango',      $q$INSERT INTO direccion(id_cliente,direccion,latitud) VALUES(%1$s,'X',95)$q$],
      ['FK inexistente',              $q$INSERT INTO pedido(id_cliente,id_direccion) VALUES(999999,999999)$q$],
      ['disponibilidad invalida',     $q$INSERT INTO domiciliario(nombre,telefono,estado_disponibilidad) VALUES('X','9','dormido')$q$]
    ];
    i INT;
BEGIN
    SELECT id_cliente INTO c1 FROM cliente WHERE correo='uno@correo.test';
    SELECT id_cliente INTO c2 FROM cliente WHERE correo='dos@correo.test';
    SELECT id_direccion INTO d1 FROM direccion WHERE id_cliente=c1;
    FOR i IN 1..array_length(casos,1) LOOP
        BEGIN
            EXECUTE format(casos[i][2], c1, c2, d1);
            INSERT INTO resultado_pruebas VALUES (casos[i][1], FALSE);  -- NO fue rechazado: mal
        EXCEPTION WHEN integrity_constraint_violation OR check_violation THEN
            INSERT INTO resultado_pruebas VALUES (casos[i][1], TRUE);   -- rechazado: bien
        END;
    END LOOP;
END $$;

SELECT caso, CASE WHEN ok THEN 'RECHAZADO (correcto)' ELSE 'ACEPTADO (ERROR)' END AS resultado
FROM resultado_pruebas;

DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM resultado_pruebas WHERE NOT ok) THEN
        RAISE EXCEPTION 'Hay restricciones que no estan funcionando';
    END IF;
END $$;

ROLLBACK;
