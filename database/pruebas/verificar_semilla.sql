-- Comprueba que los datos semilla contienen los casos que necesitan las consultas.
-- Falla (con mensaje) si falta alguno.
DO $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM cliente c WHERE NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_cliente = c.id_cliente);
  IF n = 0 THEN RAISE EXCEPTION 'Falta: clientes sin pedidos'; END IF;
  RAISE NOTICE 'Clientes sin pedidos: %', n;

  SELECT count(*) INTO n FROM domiciliario d WHERE NOT EXISTS (SELECT 1 FROM servicio_domicilio s WHERE s.id_domiciliario = d.id_domiciliario);
  IF n = 0 THEN RAISE EXCEPTION 'Falta: domiciliarios sin servicios'; END IF;
  RAISE NOTICE 'Domiciliarios sin servicios: %', n;

  SELECT count(*) INTO n FROM producto pr WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido dp WHERE dp.id_producto = pr.id_producto);
  IF n = 0 THEN RAISE EXCEPTION 'Falta: productos nunca pedidos'; END IF;
  RAISE NOTICE 'Productos nunca pedidos: %', n;

  SELECT count(*) INTO n FROM (SELECT DISTINCT barrio FROM direccion) b
   WHERE NOT EXISTS (SELECT 1 FROM pedido p JOIN direccion d ON d.id_direccion = p.id_direccion WHERE d.barrio = b.barrio);
  IF n = 0 THEN RAISE EXCEPTION 'Falta: barrios sin domicilios'; END IF;
  RAISE NOTICE 'Barrios sin domicilios: %', n;

  SELECT count(DISTINCT estado_pedido) INTO n FROM pedido;
  IF n < 5 THEN RAISE EXCEPTION 'Faltan estados de pedido (hay %)', n; END IF;
  SELECT count(DISTINCT estado_servicio) INTO n FROM servicio_domicilio;
  IF n < 5 THEN RAISE EXCEPTION 'Faltan estados de servicio (hay %)', n; END IF;
  SELECT count(*) INTO n FROM pedido;
  IF n < 1000 THEN RAISE EXCEPTION 'Volumen insuficiente en pedido (%)', n; END IF;
  RAISE NOTICE 'Semilla OK: % pedidos, todos los casos presentes.', n;
END $$;
