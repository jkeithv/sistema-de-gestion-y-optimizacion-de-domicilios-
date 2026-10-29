-- =====================================================================
-- BANCO DE CONSULTAS - Entrega 2 (Sistema de gestion y optimizacion de domicilios)
-- Se ejecuta sobre la base con migraciones 001-013 y los datos semilla cargados:
--   .\database\reconstruir.ps1 -ConDatos
--   psql -d domicilios_test -f database/consultas/banco_de_consultas.sql
--
-- Cada consulta indica: la pregunta de negocio, las tablas, la tecnica y el
-- resultado esperado calculado a mano a partir de como se generaron los datos.
-- Cumple los minimos de la rubrica:
--   * reunion de 3+ tablas ........ Q2, Q6, Q8, Q9, Q11
--   * "los que no tienen" ......... Q4, Q5, Q5b (LEFT JOIN ... IS NULL)
--   * GROUP BY + HAVING ........... Q3, Q5b
--   * subconsulta / CTE ........... Q3 y Q8 (subconsulta), Q7 y Q10 (CTE)
--   * vista creada y consultada ... Q11 (v_servicio_entregado)
--
-- CUIDADO con los totales inflados: pedido -> detalle_pedido es 1:N. Si se reune
-- y luego se cuenta con count(*), cada pedido se cuenta tantas veces como lineas
-- tenga. Por eso Q1 usa count(DISTINCT ...) y Q7 y la vista agregan el detalle
-- ANTES de reunir con otras tablas.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q1. Ingresos por periodo.
-- Pregunta: ¿Cuantos pedidos se entregaron cada mes y cuanto se vendio?
-- Tablas: pedido, detalle_pedido (reunion 1:N).
-- Tecnica: GROUP BY por mes; count(DISTINCT) para no inflar pedidos.
-- Esperado: 10 filas (ene-oct 2026); la suma de pedidos_entregados = 5686
--           (6000 pedidos - 299 cancelados - 15 recientes sin entregar).
-- ---------------------------------------------------------------------
SELECT date_trunc('month', p.fecha_hora)::date              AS mes,
       count(DISTINCT p.id_pedido)                          AS pedidos_entregados,
       sum(d.cantidad * d.precio_unitario)                  AS ventas_cop
FROM pedido p
JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
WHERE p.estado_pedido = 'entregado'
GROUP BY date_trunc('month', p.fecha_hora)
ORDER BY mes;


-- Contraejemplo (NO usar): si se reemplaza count(DISTINCT p.id_pedido) por count(*),
-- el resultado sumaria 14663 "pedidos" en lugar de 5686, porque la reunion con
-- detalle_pedido repite cada pedido una vez por cada linea de detalle.
-- Esa es la razon de count(DISTINCT ...) aqui y de agregar antes en Q7 y en la vista.

-- ---------------------------------------------------------------------
-- Q2. Domicilios por zona (barrio) y tiempo de entrega.
-- Pregunta: ¿Que barrios concentran mas domicilios y cuanto tardan en promedio
--           desde que se asigna el servicio hasta la entrega?
-- Tablas: servicio_domicilio, pedido, direccion (3 tablas).
-- Esperado: 13 barrios; la suma de domicilios = 5686. 'Los Campanos' y
--           'Villa Rocio' no aparecen (ver Q5b).
-- ---------------------------------------------------------------------
SELECT di.barrio,
       count(*)                                                                   AS domicilios_entregados,
       round(avg(extract(epoch FROM s.fecha_entrega - s.fecha_asignacion) / 60)::numeric, 1) AS minutos_promedio
FROM servicio_domicilio s
JOIN pedido    p  ON p.id_pedido    = s.id_pedido
JOIN direccion di ON di.id_direccion = p.id_direccion
WHERE s.estado_servicio = 'entregado'
GROUP BY di.barrio
ORDER BY domicilios_entregados DESC;


-- ---------------------------------------------------------------------
-- Q3. Repartidores por encima del promedio de tiempo.
-- Pregunta: ¿Que domiciliarios con trayectoria (100+ entregas) tardan, en
--           promedio, mas que el promedio general de la empresa?
-- Tablas: domiciliario, servicio_domicilio.
-- Tecnica: GROUP BY + HAVING con subconsulta escalar para el promedio general.
-- Esperado: un subconjunto de los 27 domiciliarios con entregas (aprox. la
--           mitad); los ids 28-30 (sin servicios) nunca aparecen.
-- ---------------------------------------------------------------------
SELECT dom.id_domiciliario,
       dom.nombre,
       count(*)                                                                    AS entregas,
       round(avg(extract(epoch FROM s.fecha_entrega - s.fecha_asignacion) / 60)::numeric, 2) AS minutos_promedio
FROM domiciliario dom
JOIN servicio_domicilio s ON s.id_domiciliario = dom.id_domiciliario
WHERE s.estado_servicio = 'entregado'
GROUP BY dom.id_domiciliario, dom.nombre
HAVING count(*) >= 100
   AND avg(s.fecha_entrega - s.fecha_asignacion) >
       (SELECT avg(fecha_entrega - fecha_asignacion)
        FROM servicio_domicilio
        WHERE estado_servicio = 'entregado')
ORDER BY minutos_promedio DESC;


-- ---------------------------------------------------------------------
-- Q4. Clientes sin pedidos  ("los que no tienen").
-- Pregunta: ¿Que clientes estan registrados pero nunca han hecho un pedido?
--           (candidatos a una campana de reactivacion)
-- Tablas: cliente LEFT JOIN pedido.
-- Esperado: 20 filas, clientes 281 a 300.
-- ---------------------------------------------------------------------
SELECT c.id_cliente, c.nombre, c.telefono
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
WHERE p.id_pedido IS NULL
ORDER BY c.id_cliente;


-- ---------------------------------------------------------------------
-- Q5. Repartidores sin entregas  ("los que no tienen").
-- Pregunta: ¿Que domiciliarios estan registrados pero nunca han tenido un
--           servicio asignado, y cual es su disponibilidad y vehiculo?
-- Tablas: domiciliario LEFT JOIN servicio_domicilio; vehiculo.
-- Esperado: 3 filas, domiciliarios 28, 29 y 30.
-- ---------------------------------------------------------------------
SELECT dom.id_domiciliario, dom.nombre, dom.estado_disponibilidad,
       (SELECT string_agg(v.tipo || ' ' || COALESCE(v.placa, 'sin placa'), ', ')
        FROM vehiculo v WHERE v.id_domiciliario = dom.id_domiciliario) AS vehiculos
FROM domiciliario dom
LEFT JOIN servicio_domicilio s ON s.id_domiciliario = dom.id_domiciliario
WHERE s.id_servicio IS NULL
ORDER BY dom.id_domiciliario;


-- ---------------------------------------------------------------------
-- Q5b. Zonas sin domicilios  ("los que no tienen" con HAVING).
-- Pregunta: ¿Que barrios tienen direcciones registradas pero nunca han
--           recibido un pedido? (zonas donde no se esta llegando)
-- Tablas: direccion LEFT JOIN pedido.
-- Esperado: 2 filas: 'Los Campanos' y 'Villa Rocio'.
-- ---------------------------------------------------------------------
SELECT di.barrio,
       count(DISTINCT di.id_cliente) AS clientes_registrados,
       count(p.id_pedido)            AS pedidos
FROM direccion di
LEFT JOIN pedido p ON p.id_direccion = di.id_direccion
GROUP BY di.barrio
HAVING count(p.id_pedido) = 0
ORDER BY di.barrio;


-- ---------------------------------------------------------------------
-- Q6. Productos mas vendidos.
-- Pregunta: ¿Cuales son los 10 productos mas vendidos (en unidades) en
--           pedidos entregados y cuanto ingreso generan?
-- Tablas: producto, detalle_pedido, pedido (3 tablas).
-- Esperado: 10 filas; los productos 29 y 30 nunca aparecen (nunca se piden).
-- ---------------------------------------------------------------------
SELECT pr.id_producto, pr.nombre,
       sum(d.cantidad)                      AS unidades,
       sum(d.cantidad * d.precio_unitario)  AS ingresos_cop
FROM producto pr
JOIN detalle_pedido d ON d.id_producto = pr.id_producto
JOIN pedido p         ON p.id_pedido   = d.id_pedido
WHERE p.estado_pedido = 'entregado'
GROUP BY pr.id_producto, pr.nombre
ORDER BY unidades DESC, pr.id_producto
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q7. Mejores clientes por gasto (CTE).
-- Pregunta: ¿Quienes son los 10 clientes que mas han comprado y cual es su
--           ticket promedio por pedido?
-- Tablas: pedido, detalle_pedido, cliente.
-- Tecnica: CTE que agrega primero el detalle POR PEDIDO; asi count(*) del
--          select final cuenta pedidos y no lineas de detalle (evita inflar).
-- Esperado: 10 filas; ningun cliente con id > 280.
-- ---------------------------------------------------------------------
WITH valor_pedido AS (
    SELECT p.id_pedido, p.id_cliente,
           sum(d.cantidad * d.precio_unitario) AS valor
    FROM pedido p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
    WHERE p.estado_pedido = 'entregado'
    GROUP BY p.id_pedido, p.id_cliente
)
SELECT c.id_cliente, c.nombre,
       count(*)           AS pedidos,
       sum(v.valor)       AS gasto_total_cop,
       round(avg(v.valor)) AS ticket_promedio_cop
FROM valor_pedido v
JOIN cliente c ON c.id_cliente = v.id_cliente
GROUP BY c.id_cliente, c.nombre
ORDER BY gasto_total_cop DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q8. Entregas retrasadas (subconsulta).
-- Pregunta: ¿Que entregas tardaron mas de una vez y media el promedio
--           general, y quien las hizo y en que barrio?
-- Tablas: servicio_domicilio, domiciliario, pedido, direccion (4 tablas).
-- Tecnica: subconsulta escalar en el WHERE con el promedio general.
-- Esperado: 20 filas (limite); todas con mas de ~57 minutos.
-- ---------------------------------------------------------------------
SELECT s.id_servicio, dom.nombre AS domiciliario, di.barrio,
       s.fecha_asignacion,
       round(extract(epoch FROM s.fecha_entrega - s.fecha_asignacion) / 60) AS minutos
FROM servicio_domicilio s
JOIN domiciliario dom ON dom.id_domiciliario = s.id_domiciliario
JOIN pedido p         ON p.id_pedido         = s.id_pedido
JOIN direccion di     ON di.id_direccion     = p.id_direccion
WHERE s.estado_servicio = 'entregado'
  AND (s.fecha_entrega - s.fecha_asignacion) >
      1.5 * (SELECT avg(fecha_entrega - fecha_asignacion)
             FROM servicio_domicilio
             WHERE estado_servicio = 'entregado')
ORDER BY minutos DESC, s.id_servicio
LIMIT 20;


-- ---------------------------------------------------------------------
-- Q9. Seguimiento: servicios activos y ultima posicion conocida.
-- Pregunta: ¿Donde esta ahora cada domiciliario que tiene un servicio en
--           curso, para quien es el pedido y a que barrio va? (R11, R12)
-- Tablas: servicio_domicilio, domiciliario, pedido, cliente, direccion + ubicacion.
-- Tecnica: LATERAL para traer solo la posicion MAS RECIENTE de cada servicio.
-- Esperado: 10 filas (3 asignado + 4 recogido + 3 en_camino).
-- ---------------------------------------------------------------------
SELECT s.id_servicio, s.estado_servicio,
       dom.nombre AS domiciliario,
       cli.nombre AS cliente,
       di.barrio  AS barrio_destino,
       u.fecha_hora AS ultima_posicion_hora,
       u.latitud, u.longitud
FROM servicio_domicilio s
JOIN domiciliario dom ON dom.id_domiciliario = s.id_domiciliario
JOIN pedido p         ON p.id_pedido         = s.id_pedido
JOIN cliente cli      ON cli.id_cliente      = p.id_cliente
JOIN direccion di     ON di.id_direccion     = p.id_direccion
CROSS JOIN LATERAL (
    SELECT fecha_hora, latitud, longitud
    FROM ubicacion
    WHERE id_servicio = s.id_servicio
    ORDER BY fecha_hora DESC
    LIMIT 1
) u
WHERE s.estado_servicio IN ('asignado', 'recogido', 'en_camino')
ORDER BY s.fecha_asignacion;


-- ---------------------------------------------------------------------
-- Q10. Asignacion sugerida: domiciliarios disponibles mas cercanos.
-- Pregunta: Para cada pedido pendiente, ¿cuales son los 3 domiciliarios
--           disponibles mas cercanos segun su ultima ubicacion registrada?
--           (apoya la decision de la central; no la reemplaza)
-- Tablas: pedido, direccion, domiciliario, ubicacion.
-- Tecnica: CTE (ultima posicion por domiciliario con DISTINCT ON) y
--          ROW_NUMBER() para quedarse con los 3 primeros de cada pedido.
-- Distancia aproximada: 1 grado de latitud ~ 111 km y de longitud ~ 109 km
--          (a la latitud de Valledupar); sin GPS real ni mapas.
-- Esperado: 15 filas (5 pedidos pendientes x 3 candidatos).
-- ---------------------------------------------------------------------
WITH ultima_pos AS (
    SELECT DISTINCT ON (id_domiciliario)
           id_domiciliario, latitud, longitud, fecha_hora
    FROM ubicacion
    ORDER BY id_domiciliario, fecha_hora DESC
),
distancias AS (
    SELECT p.id_pedido, dom.id_domiciliario, dom.nombre,
           sqrt(power(((di.latitud  - u.latitud)  * 111)::float8, 2)
              + power(((di.longitud - u.longitud) * 109)::float8, 2)) AS km
    FROM pedido p
    JOIN direccion di     ON di.id_direccion = p.id_direccion
    CROSS JOIN domiciliario dom
    JOIN ultima_pos u     ON u.id_domiciliario = dom.id_domiciliario
    WHERE p.estado_pedido = 'pendiente'
      AND dom.estado_disponibilidad = 'disponible'
),
rankeados AS (
    SELECT *, row_number() OVER (PARTITION BY id_pedido ORDER BY km) AS puesto
    FROM distancias
)
SELECT id_pedido, puesto, id_domiciliario, nombre, round(km::numeric, 2) AS km_aprox
FROM rankeados
WHERE puesto <= 3
ORDER BY id_pedido, puesto;


-- ---------------------------------------------------------------------
-- Q11. Vista creada y consultada.
-- La vista resume cada servicio entregado (cliente, barrio, domiciliario,
-- minutos y valor del pedido). El valor se calcula con una subconsulta que
-- agrega el detalle por pedido para que la vista tenga UNA fila por servicio
-- (sin duplicados por lineas de detalle).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_servicio_entregado AS
SELECT s.id_servicio,
       s.fecha_entrega::date AS fecha,
       di.barrio,
       c.nombre   AS cliente,
       dom.nombre AS domiciliario,
       round((extract(epoch FROM s.fecha_entrega - s.fecha_asignacion) / 60)::numeric, 1) AS minutos_totales,
       v.valor_pedido
FROM servicio_domicilio s
JOIN pedido p         ON p.id_pedido         = s.id_pedido
JOIN direccion di     ON di.id_direccion     = p.id_direccion
JOIN cliente c        ON c.id_cliente        = p.id_cliente
JOIN domiciliario dom ON dom.id_domiciliario = s.id_domiciliario
JOIN (SELECT id_pedido, sum(cantidad * precio_unitario) AS valor_pedido
      FROM detalle_pedido GROUP BY id_pedido) v ON v.id_pedido = p.id_pedido
WHERE s.estado_servicio = 'entregado';

-- Pregunta: ¿Que dia de la semana se vende mas y en cual se entrega mas rapido?
-- Esperado: 7 filas (lunes a domingo); la suma de domicilios = 5686,
--           igual al numero de filas de la vista.
SELECT (ARRAY['lunes','martes','miercoles','jueves','viernes','sabado','domingo'])
           [extract(isodow FROM fecha)::int]   AS dia_semana,
       count(*)                                 AS domicilios,
       sum(valor_pedido)                        AS ventas_cop,
       round(avg(minutos_totales), 1)           AS minutos_promedio
FROM v_servicio_entregado
GROUP BY extract(isodow FROM fecha)
ORDER BY extract(isodow FROM fecha);
