-- 001_datos_semilla.sql
-- Datos FICTICIOS pero coherentes para Valledupar. Sin datos personales reales.
-- Es DETERMINISTA (sin random()): cada reconstruccion produce exactamente los
-- mismos datos, asi los resultados de las consultas se pueden verificar a mano.
-- Ejecutar DESPUES de las migraciones 001-013.
--
-- Volumen: 300 clientes, 600 direcciones, 30 productos, 6.000 pedidos,
-- 5.845 servicios, 15.000 lineas de detalle, 22.917 ubicaciones, 11.538 rutas.
--
-- Casos pensados para las consultas del negocio:
--   * clientes 281-300: nunca hacen pedidos ("clientes sin pedidos").
--   * barrios 'Los Campanos' y 'Villa Rocio': solo tienen direcciones de esos
--     clientes, asi que nunca reciben domicilios ("barrios sin domicilios").
--   * domiciliarios 28-30: nunca tienen servicios ("repartidores sin entregas").
--   * productos 29-30: nunca se piden.
--   * estados variados: entregado, cancelado (con y sin servicio), pendiente,
--     asignado, en_camino (servicio recogido / en_camino).
--   * precio_unitario historico: pedidos anteriores a junio de 2026 tienen un
--     precio ~8 % menor que el precio actual del producto.

BEGIN;

-- ---------- Listas de apoyo (temporal, se descarta al final) ----------
CREATE TEMP TABLE _ref AS SELECT
  ARRAY['Carlos','Luis','Andrea','Maria','Jose','Laura','Juan','Paola','Jorge','Diana',
        'Camilo','Sandra','Daniel','Natalia','Felipe','Marcela','Miguel','Viviana','Sergio','Luz',
        'Ricardo','Yesenia','Alvaro','Karen','Hernan','Milena','Edwin','Johana','Fabian','Liliana',
        'Oscar','Mayra','Wilson','Katia','Rafael','Dayana','Ivan','Elena','Gustavo','Rosa']::text[] AS nombres,
  ARRAY['Pacheco','Daza','Maestre','Cuello','Ovalle','Mendoza','Brito','Araujo','Peñaloza','Zuleta',
        'Molina','Ariza','Quintero','Redondo','Orozco','Fuentes','Cabrera','Lopez','Vega','Rojas',
        'Castro','Salcedo','Pineda','Barrios','Mejia','Sierra','Oñate','Ustariz','Nieves','Granados',
        'Ramos','Torres','Duran','Escobar','Montero','Bolaño','Cotes','Villazon','Rincon','Maya']::text[] AS apellidos,
  ARRAY['Centro','Los Músicos','Cañaguate','Novalito','Alfonso López','Villa Corelca','El Pueblito',
        'Los Mayales','Sicarare','Dangond','Garupal','Nueva Esperanza','Villa Clara',
        'Los Campanos','Villa Rocío']::text[] AS barrios;

-- ---------- Centrales y empleados ----------
INSERT INTO central (id_central, nombre, telefono, direccion) VALUES
  (1, 'Central Domicilios Centro', '6050000001', 'Calle 16 # 5-30, Centro'),
  (2, 'Central Domicilios Norte',  '6050000002', 'Carrera 19 # 9-45, Los Músicos'),
  (3, 'Central Domicilios Sur',    '6050000003', 'Calle 6 # 12-80, Cañaguate');

INSERT INTO empleado_central (id_empleado, id_central, nombre, telefono, correo, cargo) VALUES
  (1, 1, 'Marcela Ovalle Brito',    '3220000001', 'movalle@domicilios.ejemplo',   'Coordinadora'),
  (2, 1, 'Camilo Zuleta Daza',      '3220000002', 'czuleta@domicilios.ejemplo',   'Despachador'),
  (3, 1, 'Yesenia Cuello Mendoza',  '3220000003', 'ycuello@domicilios.ejemplo',   'Despachadora'),
  (4, 2, 'Hernan Araujo Molina',    '3220000004', 'haraujo@domicilios.ejemplo',   'Coordinador'),
  (5, 2, 'Liliana Ariza Quintero',  '3220000005', 'lariza@domicilios.ejemplo',    'Despachadora'),
  (6, 2, 'Fabian Redondo Orozco',   '3220000006', 'fredondo@domicilios.ejemplo',  'Despachador'),
  (7, 3, 'Mayra Fuentes Cabrera',   '3220000007', 'mfuentes@domicilios.ejemplo',  'Coordinadora'),
  (8, 3, 'Wilson Lopez Vega',       '3220000008', 'wlopez@domicilios.ejemplo',    'Despachador');

-- ---------- Domiciliarios y vehículos ----------
INSERT INTO domiciliario (id_domiciliario, nombre, telefono, estado_disponibilidad)
SELECT i,
       r.nombres[1 + (i*3) % 40] || ' ' || r.apellidos[1 + (i*5) % 40] || ' ' || r.apellidos[1 + (i*9 + 2) % 40],
       '311' || lpad(i::text, 7, '0'),
       CASE WHEN i IN (11, 22, 29, 30) THEN 'desconectado' ELSE 'disponible' END
FROM _ref r, generate_series(1, 30) AS g(i);

INSERT INTO vehiculo (id_domiciliario, tipo, placa, estado)
SELECT i,
       CASE WHEN i % 7 = 0 THEN 'bicicleta' WHEN i % 10 = 0 THEN 'carro' ELSE 'moto' END,
       CASE WHEN i % 7 = 0 THEN NULL
            WHEN i % 10 = 0 THEN chr(65 + (i*3) % 26) || chr(65 + (i*5) % 26) || chr(65 + (i*7) % 26)
                                 || lpad(((i*37) % 900 + 100)::text, 3, '0')
            ELSE chr(65 + (i*3) % 26) || chr(65 + (i*5) % 26) || chr(65 + (i*7) % 26)
                 || lpad(((i*13) % 90 + 10)::text, 2, '0') || chr(65 + (i*11) % 26) END,
       'activo'
FROM generate_series(1, 30) AS g(i);

-- Segundos vehículos (en taller o fuera de servicio)
INSERT INTO vehiculo (id_domiciliario, tipo, placa, estado) VALUES
  (3,  'moto',  'QRS11T', 'mantenimiento'),
  (12, 'moto',  'TUV22W', 'inactivo'),
  (20, 'carro', 'XYZ333', 'mantenimiento');

-- ---------- Productos (precios en COP) ----------
INSERT INTO producto (id_producto, nombre, descripcion, precio) VALUES
  (1,  'Hamburguesa sencilla',     'Carne, queso, lechuga y tomate',            16000),
  (2,  'Hamburguesa doble',        'Doble carne con queso y tocineta',          24000),
  (3,  'Perro caliente especial',  'Salchicha, papa ripio y salsas',            12000),
  (4,  'Pizza personal',           'Pizza de queso y jamón de 20 cm',           18000),
  (5,  'Pizza familiar',           'Pizza mixta de 40 cm',                      46000),
  (6,  'Arepa con huevo',          'Arepa frita rellena de huevo',               4500),
  (7,  'Arepa de queso',           'Arepa asada con queso costeño',              5000),
  (8,  'Empanada de carne',        'Empanada frita de carne desmechada',         2500),
  (9,  'Pollo asado 1/4',          'Cuarto de pollo con papa y ensalada',       17000),
  (10, 'Pollo asado entero',       'Pollo entero con papas y ensalada',         52000),
  (11, 'Carne desmechada',         'Plato con arroz, yuca y ensalada',          20000),
  (12, 'Sancocho de gallina',      'Porción individual con arroz',              22000),
  (13, 'Mondongo',                 'Porción individual',                        21000),
  (14, 'Ensalada de frutas',       'Frutas de temporada con helado',             9000),
  (15, 'Jugo natural 12 oz',       'Jugo en agua o en leche',                    6000),
  (16, 'Limonada de coco',         'Vaso de 16 oz',                              8000),
  (17, 'Gaseosa 400 ml',           'Gaseosa personal',                           3500),
  (18, 'Agua 600 ml',              'Agua embotellada',                           2500),
  (19, 'Cerveza nacional',         'Botella de 330 ml',                          4500),
  (20, 'Helado 2 bolas',           'Helado artesanal en vaso',                   7000),
  (21, 'Pan de bono x6',           'Bolsa de seis unidades',                     8000),
  (22, 'Torta de chocolate',       'Porción individual',                         9500),
  (23, 'Acetaminofén 500 mg x10',  'Caja de 10 tabletas',                        3000),
  (24, 'Suero oral',               'Sobre de sales de rehidratación',            4000),
  (25, 'Crema dental',             'Tubo de 75 ml',                              7500),
  (26, 'Papel higiénico x4',       'Paquete de 4 rollos',                       10000),
  (27, 'Arroz 1 kg',               'Bolsa de arroz blanco',                      5500),
  (28, 'Leche 1 litro',            'Leche entera en bolsa',                      4800),
  (29, 'Combo parrilla para 4',    'Carnes surtidas para cuatro personas',      95000),
  (30, 'Torta tres leches entera', 'Torta de 12 porciones',                     58000);

-- ---------- Clientes y direcciones ----------
INSERT INTO cliente (id_cliente, nombre, telefono, correo)
SELECT i,
       r.nombres[1 + i % 40] || ' ' || r.apellidos[1 + (i*7) % 40] || ' ' || r.apellidos[1 + (i*11 + 3) % 40],
       '300' || lpad(i::text, 7, '0'),
       CASE WHEN i % 9 = 0 THEN NULL
            ELSE lower(substr(r.nombres[1 + i % 40], 1, 1) || translate(r.apellidos[1 + (i*7) % 40], 'ñ', 'n') || i)
                 || '@correo.ejemplo' END
FROM _ref r, generate_series(1, 300) AS g(i);

INSERT INTO direccion (id_direccion, id_cliente, direccion, barrio, ciudad, latitud, longitud)
SELECT row_number() OVER (ORDER BY c.ci, j.jn),
       c.ci,
       CASE WHEN (c.ci + j.jn) % 2 = 0 THEN 'Calle ' ELSE 'Carrera ' END
         || (5 + (c.ci*3 + j.jn) % 40) || ' # ' || (1 + (c.ci*7 + j.jn) % 30) || '-' || (10 + (c.ci*11 + j.jn*5) % 80),
       CASE WHEN c.ci > 280 THEN r.barrios[14 + c.ci % 2]
            ELSE r.barrios[1 + (c.ci + j.jn) % 13] END,
       'Valledupar',
       round((10.430 + ((c.ci*37 + j.jn*11) % 100) / 1000.0)::numeric, 6),
       round((-73.280 + ((c.ci*53 + j.jn*7) % 100) / 1000.0)::numeric, 6)
FROM _ref r, generate_series(1, 300) AS c(ci), generate_series(1, 3) AS j(jn)
WHERE j.jn <= 1 + c.ci % 3;

-- ---------- Pedidos (6.000, ~20 por día desde el 1-ene-2026) ----------
CREATE TEMP TABLE _dir AS
SELECT id_direccion, id_cliente,
       row_number() OVER (PARTITION BY id_cliente ORDER BY id_direccion) AS rn,
       count(*)     OVER (PARTITION BY id_cliente) AS k
FROM direccion;

INSERT INTO pedido (id_pedido, id_cliente, id_direccion, fecha_hora, estado_pedido, observaciones)
SELECT n,
       1 + (n*13) % 280,                       -- clientes 281-300 nunca piden
       d.id_direccion,
       date '2026-01-01' + ((n - 1) / 20) * interval '1 day'
         + interval '10 hours' + (((n - 1) % 20) * 40) * interval '1 minute',
       CASE WHEN n >= 5994 THEN 'en_camino'
            WHEN n >= 5991 THEN 'asignado'
            WHEN n >= 5986 THEN 'pendiente'
            WHEN n % 20 = 0 THEN 'cancelado'
            ELSE 'entregado' END,
       (ARRAY[NULL, 'Sin cebolla', 'Llamar al llegar', 'Dejar con el portero',
              'Pagar en efectivo', 'Sin picante', NULL])[1 + n % 7]
FROM generate_series(1, 6000) AS g(n)
JOIN _dir d ON d.id_cliente = 1 + (n*13) % 280
           AND d.rn = 1 + (n % d.k);

-- ---------- Detalle de pedido (1 a 4 productos; productos 29-30 nunca) ----------
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT p.id_pedido,
       pr.id_producto,
       1 + (p.id_pedido * q.k) % 3,
       CASE WHEN p.fecha_hora < timestamp '2026-06-01'
            THEN round(pr.precio * 0.92 / 100) * 100      -- precio histórico menor
            ELSE pr.precio END
FROM pedido p
CROSS JOIN LATERAL generate_series(1, 1 + p.id_pedido % 4) AS q(k)
JOIN producto pr ON pr.id_producto = 1 + ((p.id_pedido + q.k * 7) % 28);

-- ---------- Servicios de domicilio ----------
-- Un servicio por pedido, salvo pendientes y la mitad de los cancelados.
INSERT INTO servicio_domicilio (id_servicio, id_pedido, id_empleado, id_domiciliario,
                                fecha_asignacion, fecha_recogida, fecha_entrega, estado_servicio)
SELECT id_pedido, id_pedido,
       1 + id_pedido % 8,
       1 + (id_pedido * 7) % 27,                  -- domiciliarios 28-30 nunca
       a,
       CASE WHEN estado_pedido IN ('entregado', 'en_camino') THEN rec END,
       CASE WHEN estado_pedido = 'entregado'
            THEN rec + (10 + (id_pedido * 3) % 35 + CASE WHEN id_pedido % 50 = 0 THEN 60 ELSE 0 END) * interval '1 minute' END,
       CASE estado_pedido
            WHEN 'entregado' THEN 'entregado'
            WHEN 'cancelado' THEN 'cancelado'
            WHEN 'asignado'  THEN 'asignado'
            ELSE CASE WHEN id_pedido >= 5997 THEN 'recogido' ELSE 'en_camino' END END
FROM (
  SELECT p.id_pedido, p.estado_pedido,
         p.fecha_hora + (2 + p.id_pedido % 9) * interval '1 minute' AS a,
         p.fecha_hora + (2 + p.id_pedido % 9 + 5 + p.id_pedido % 11) * interval '1 minute' AS rec
  FROM pedido p
  WHERE p.estado_pedido IN ('entregado', 'asignado', 'en_camino')
     OR (p.estado_pedido = 'cancelado' AND p.id_pedido % 40 = 0)
) s
ORDER BY id_pedido;

-- Disponibilidad coherente: quien tiene un servicio activo está ocupado.
UPDATE domiciliario SET estado_disponibilidad = 'ocupado'
WHERE id_domiciliario IN (SELECT id_domiciliario FROM servicio_domicilio
                          WHERE estado_servicio IN ('asignado', 'recogido', 'en_camino'));

-- ---------- Ubicaciones y rutas ----------
CREATE TEMP TABLE _srv AS
SELECT s.*, d.latitud AS d_lat, d.longitud AS d_lon,
       round((10.460 + ((s.id_domiciliario * 13) % 20) / 1000.0)::numeric, 6) AS o_lat,
       round((-73.260 + ((s.id_domiciliario * 17) % 20) / 1000.0)::numeric, 6) AS o_lon
FROM servicio_domicilio s
JOIN pedido p    ON p.id_pedido = s.id_pedido
JOIN direccion d ON d.id_direccion = p.id_direccion;

INSERT INTO ubicacion (id_domiciliario, id_servicio, fecha_hora, latitud, longitud)
SELECT s.id_domiciliario, s.id_servicio,
       CASE g.k WHEN 0 THEN s.fecha_asignacion
                WHEN 1 THEN s.fecha_recogida
                WHEN 2 THEN COALESCE(s.fecha_recogida + (s.fecha_entrega - s.fecha_recogida) / 2,
                                     s.fecha_recogida + interval '5 minutes')
                ELSE s.fecha_entrega END,
       round((s.o_lat + (s.d_lat - s.o_lat) * CASE g.k WHEN 0 THEN 0 WHEN 1 THEN 0.05 WHEN 2 THEN 0.6 ELSE 1 END)::numeric, 6),
       round((s.o_lon + (s.d_lon - s.o_lon) * CASE g.k WHEN 0 THEN 0 WHEN 1 THEN 0.05 WHEN 2 THEN 0.6 ELSE 1 END)::numeric, 6)
FROM _srv s CROSS JOIN generate_series(0, 3) AS g(k)
WHERE g.k = 0
   OR (g.k IN (1, 2) AND s.fecha_recogida IS NOT NULL)
   OR (g.k = 3 AND s.fecha_entrega IS NOT NULL)
ORDER BY s.id_servicio, g.k;

-- Rutas: una al asignar y, si hubo recogida, otra de actualización.
-- El tráfico depende de la hora (picos al mediodía y al final de la tarde).
INSERT INTO ruta (id_servicio, fecha_hora_consulta, origen_latitud, origen_longitud,
                  destino_latitud, destino_longitud, distancia_km, tiempo_estimado_min, condicion_trafico)
SELECT x.id_servicio, x.f, x.o_lat, x.o_lon, x.d_lat, x.d_lon, x.dist,
       ceil(x.dist * CASE t.trafico WHEN 'fluido' THEN 2.5 WHEN 'moderado' THEN 3.5 ELSE 5 END)::int,
       t.trafico
FROM (
  SELECT s.id_servicio, s.o_lat, s.o_lon, s.d_lat, s.d_lon, g.k,
         CASE g.k WHEN 1 THEN s.fecha_asignacion ELSE s.fecha_recogida END AS f,
         round((sqrt(power(((s.d_lat - s.o_lat) * 111)::float8, 2)
                   + power(((s.d_lon - s.o_lon) * 109)::float8, 2)) * 1.3)::numeric, 2) AS dist
  FROM _srv s CROSS JOIN generate_series(1, 2) AS g(k)
) x
CROSS JOIN LATERAL (
  SELECT CASE WHEN extract(hour FROM x.f) IN (12, 13, 18, 19) THEN 'congestionado'
              WHEN extract(hour FROM x.f) IN (11, 14, 17, 20) THEN 'moderado'
              ELSE 'fluido' END AS trafico
) t
WHERE x.f IS NOT NULL
ORDER BY x.id_servicio, x.k;

-- ---------- Reajustar las secuencias (se insertaron ids explícitos) ----------
DO $$
DECLARE t text; c text;
BEGIN
  FOR t, c IN SELECT * FROM (VALUES
      ('cliente','id_cliente'), ('direccion','id_direccion'), ('producto','id_producto'),
      ('pedido','id_pedido'), ('central','id_central'), ('empleado_central','id_empleado'),
      ('domiciliario','id_domiciliario'), ('vehiculo','id_vehiculo'),
      ('servicio_domicilio','id_servicio'), ('ubicacion','id_ubicacion'), ('ruta','id_ruta')
    ) AS v(t, c)
  LOOP
    EXECUTE format('SELECT setval(pg_get_serial_sequence(%L, %L), (SELECT COALESCE(MAX(%I), 1) FROM %I))', t, c, c, t);
  END LOOP;
END $$;

COMMIT;
ANALYZE;

-- Resumen de lo cargado
SELECT 'cliente' AS tabla, count(*) AS filas FROM cliente
UNION ALL SELECT 'direccion', count(*) FROM direccion
UNION ALL SELECT 'producto', count(*) FROM producto
UNION ALL SELECT 'pedido', count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido
UNION ALL SELECT 'central', count(*) FROM central
UNION ALL SELECT 'empleado_central', count(*) FROM empleado_central
UNION ALL SELECT 'domiciliario', count(*) FROM domiciliario
UNION ALL SELECT 'vehiculo', count(*) FROM vehiculo
UNION ALL SELECT 'servicio_domicilio', count(*) FROM servicio_domicilio
UNION ALL SELECT 'ubicacion', count(*) FROM ubicacion
UNION ALL SELECT 'ruta', count(*) FROM ruta;
