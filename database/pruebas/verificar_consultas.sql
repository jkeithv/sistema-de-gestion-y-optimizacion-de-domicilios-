-- Verifica los resultados del banco de consultas contra calculos hechos A MANO
-- a partir de como se generaron los datos semilla (seeds/001_datos_semilla.sql).
-- Requiere haber ejecutado antes consultas/banco_de_consultas.sql (crea la vista).
-- Si algun numero no coincide, falla con un mensaje.

CREATE FUNCTION pg_temp.chequear(descripcion TEXT, obtenido NUMERIC, esperado NUMERIC) RETURNS VOID AS $f$
BEGIN
  IF obtenido IS DISTINCT FROM esperado THEN
    RAISE EXCEPTION 'FALLA: % -> obtenido %, esperado %', descripcion, obtenido, esperado;
  END IF;
  RAISE NOTICE 'OK: % = %', descripcion, obtenido;
END $f$ LANGUAGE plpgsql;

-- ---- Cuentas a mano de los estados --------------------------------------
-- 6000 pedidos. Cancelados: multiplos de 20 hasta el 5985 -> 5985/20 = 299.
-- Los 15 ultimos (5986-6000) estan en curso. Entregados = 6000 - 299 - 15 = 5686.
-- Servicios: 5686 entregados + 149 cancelados con servicio (multiplos de 40
-- hasta 5985 -> 149) + 10 activos = 5845.
SELECT pg_temp.chequear('pedidos entregados',  (SELECT count(*) FROM pedido WHERE estado_pedido = 'entregado'), 5686);
SELECT pg_temp.chequear('pedidos cancelados',  (SELECT count(*) FROM pedido WHERE estado_pedido = 'cancelado'), 299);
SELECT pg_temp.chequear('servicios en total',  (SELECT count(*) FROM servicio_domicilio), 5845);

-- ---- Q1: ingresos por mes ----------------------------------------------
-- Pedidos entregados sumados por mes = 5686 (si saliera mas, hay totales inflados).
SELECT pg_temp.chequear('Q1 meses con ventas', (SELECT count(DISTINCT date_trunc('month', fecha_hora)) FROM pedido WHERE estado_pedido = 'entregado'), 10);
SELECT pg_temp.chequear('Q1 suma de pedidos por mes', (SELECT sum(c) FROM (
    SELECT count(DISTINCT p.id_pedido) AS c FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
    WHERE p.estado_pedido = 'entregado' GROUP BY date_trunc('month', p.fecha_hora)) q), 5686);
-- Ventas totales calculadas por OTRO camino (desde servicio_domicilio) deben coincidir.
SELECT pg_temp.chequear('Q1 ventas totales (dos caminos)',
  (SELECT sum(d.cantidad * d.precio_unitario) FROM pedido p JOIN detalle_pedido d USING (id_pedido) WHERE p.estado_pedido = 'entregado'),
  (SELECT sum(d.cantidad * d.precio_unitario) FROM servicio_domicilio s JOIN detalle_pedido d ON d.id_pedido = s.id_pedido WHERE s.estado_servicio = 'entregado'));

-- ---- Valor del pedido 1, calculado a mano --------------------------------
-- Pedido 1 tiene 1 + (1 % 4) = 2 lineas: productos 1+((1+7)%28)=9 y 1+((1+14)%28)=16.
-- Cantidades: 1+(1*1)%3 = 2 y 1+(1*2)%3 = 3. Fecha ene-2026 (< jun) -> precio historico:
--   producto 9:  17.000 * 0,92 = 15.640 -> redondeo a 100 -> 15.600
--   producto 16:  8.000 * 0,92 =  7.360 -> redondeo a 100 ->  7.400
-- Valor = 2*15.600 + 3*7.400 = 31.200 + 22.200 = 53.400
SELECT pg_temp.chequear('valor del pedido 1 (a mano: 53.400)',
  (SELECT sum(cantidad * precio_unitario) FROM detalle_pedido WHERE id_pedido = 1), 53400);

-- ---- Q2: barrios con domicilios ------------------------------------------
SELECT pg_temp.chequear('Q2 barrios con domicilios', (SELECT count(DISTINCT di.barrio) FROM servicio_domicilio s
    JOIN pedido p ON p.id_pedido = s.id_pedido JOIN direccion di ON di.id_direccion = p.id_direccion
    WHERE s.estado_servicio = 'entregado'), 13);

-- ---- Q4, Q5, Q5b: "los que no tienen" -------------------------------------
-- Clientes 281-300 nunca piden (los pedidos usan 1 + (n*13) % 280, siempre <= 280).
SELECT pg_temp.chequear('Q4 clientes sin pedidos', (SELECT count(*) FROM cliente c LEFT JOIN pedido p ON p.id_cliente = c.id_cliente WHERE p.id_pedido IS NULL), 20);
SELECT pg_temp.chequear('Q4 primer cliente sin pedidos', (SELECT min(c.id_cliente) FROM cliente c LEFT JOIN pedido p ON p.id_cliente = c.id_cliente WHERE p.id_pedido IS NULL), 281);
-- Domiciliarios asignados a 1 + (n*7) % 27, es decir 1..27; los ids 28, 29, 30 nunca.
SELECT pg_temp.chequear('Q5 domiciliarios sin servicios', (SELECT count(*) FROM domiciliario d LEFT JOIN servicio_domicilio s ON s.id_domiciliario = d.id_domiciliario WHERE s.id_servicio IS NULL), 3);
SELECT pg_temp.chequear('Q5 primer domiciliario sin servicios', (SELECT min(d.id_domiciliario) FROM domiciliario d LEFT JOIN servicio_domicilio s ON s.id_domiciliario = d.id_domiciliario WHERE s.id_servicio IS NULL), 28);
-- Solo los clientes 281-300 viven en 'Los Campanos' y 'Villa Rocio' (10 cada uno).
SELECT pg_temp.chequear('Q5b barrios sin domicilios', (SELECT count(*) FROM (
    SELECT di.barrio FROM direccion di LEFT JOIN pedido p ON p.id_direccion = di.id_direccion
    GROUP BY di.barrio HAVING count(p.id_pedido) = 0) q), 2);

-- ---- Q6: productos nunca vendidos ------------------------------------------
-- Productos pedidos: 1 + ((n + 7k) % 28) -> 1..28; los 29 y 30 nunca.
SELECT pg_temp.chequear('Q6 productos que nunca se piden', (SELECT count(*) FROM producto pr
    WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.id_producto = pr.id_producto)), 2);

-- ---- Q7: el CTE no infla los conteos -------------------------------------------
-- La suma de 'pedidos' de TODOS los clientes en el CTE debe ser 5686.
SELECT pg_temp.chequear('Q7 pedidos contados en el CTE', (SELECT count(*) FROM (
    SELECT p.id_pedido FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
    WHERE p.estado_pedido = 'entregado' GROUP BY p.id_pedido) q), 5686);

-- ---- Q9, Q10: servicios activos y asignacion --------------------------------
-- Pedidos 5991-5993 asignado, 5994-5996 en_camino y 5997-6000 recogido = 10 servicios activos.
SELECT pg_temp.chequear('Q9 servicios activos', (SELECT count(*) FROM servicio_domicilio WHERE estado_servicio IN ('asignado','recogido','en_camino')), 10);
-- Pedidos pendientes: 5986-5990 = 5 (cada uno con 3 candidatos = 15 filas en Q10).
SELECT pg_temp.chequear('Q10 pedidos pendientes', (SELECT count(*) FROM pedido WHERE estado_pedido = 'pendiente'), 5);

-- ---- Q11: la vista tiene UNA fila por servicio entregado ----------------------
SELECT pg_temp.chequear('Q11 filas de la vista', (SELECT count(*) FROM v_servicio_entregado), 5686);
SELECT pg_temp.chequear('Q11 ventas de la vista = Q1',
  (SELECT sum(valor_pedido) FROM v_servicio_entregado),
  (SELECT sum(d.cantidad * d.precio_unitario) FROM pedido p JOIN detalle_pedido d USING (id_pedido) WHERE p.estado_pedido = 'entregado'));
