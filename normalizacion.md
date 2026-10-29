# Auditoría de normalización

**Proyecto:** Sistema de Gestión y Optimización de Domicilios · Base de Datos I
**Responsable:** Katherin · **Base:** esquema relacional de la Entrega 1

## 1. Criterio

Para cada tabla se listan las dependencias funcionales (DF) relevantes, las claves candidatas y se verifica:

- **1FN:** todos los atributos son atómicos y no hay grupos repetidos.
- **2FN:** ningún atributo no clave depende de solo una parte de una clave compuesta. Solo aplica a `DETALLE_PEDIDO`, la única tabla con clave compuesta.
- **3FN:** no hay dependencias transitivas entre atributos no clave.
- **BCNF:** el determinante de toda DF es una superclave.



## 2. Verificación tabla por tabla

| Tabla | Claves candidatas | DF relevantes | Veredicto |
|---|---|---|---|
| CLIENTE | `idCliente` | `idCliente -> nombre, telefono, correo` | 3FN/BCNF |
| DIRECCION | `idDireccion` | `idDireccion -> idCliente, direccion, barrio, ciudad, latitud, longitud` | 3FN/BCNF (ver nota N1) |
| PEDIDO | `idPedido` | `idPedido -> idCliente, idDireccion, fechaHora, estadoPedido, observaciones`; **`idDireccion -> idCliente`** | **Viola 3FN: hallazgo H1** |
| PRODUCTO | `idProducto` | `idProducto -> nombre, descripcion, precio` | 3FN/BCNF |
| DETALLE_PEDIDO | `(idPedido, idProducto)` | `(idPedido, idProducto) -> cantidad, precioUnitario` | 2FN/3FN/BCNF (excepción E1 documentada) |
| CENTRAL | `idCentral` | `idCentral -> nombre, telefono, direccion` | 3FN/BCNF |
| EMPLEADO_CENTRAL | `idEmpleado` | `idEmpleado -> idCentral, nombre, telefono, correo, cargo` | 3FN/BCNF |
| DOMICILIARIO | `idDomiciliario` | `idDomiciliario -> nombre, telefono, estadoDisponibilidad` | 3FN/BCNF |
| VEHICULO | `idVehiculo`, `placa` | `idVehiculo -> idDomiciliario, tipo, placa, estado`; `placa -> idVehiculo, ...` | BCNF (cada determinante es clave) |
| SERVICIO_DOMICILIO | `idServicio`, `idPedido` | `idServicio -> idPedido, idEmpleado, idDomiciliario, fechaAsignacion, fechaRecogida, fechaEntrega, estadoServicio`; `idPedido -> idServicio, ...` | BCNF (excepción E3 documentada) |
| UBICACION | `idUbicacion`, `(idDomiciliario, fechaHora)` | `idUbicacion -> idDomiciliario, idServicio, fechaHora, latitud, longitud`; `(idDomiciliario, fechaHora) -> idServicio, latitud, longitud`; **`idServicio -> idDomiciliario`** | **Viola 3FN: hallazgo H2** |
| RUTA | `idRuta` | `idRuta -> idServicio, fechaHoraConsulta, origen*, destino*, distanciaKm, tiempoEstimadoMin, condicionTrafico` | 3FN/BCNF (excepción E2 documentada) |

**1FN:** se cumple en todas las tablas. `direccion` es una cadena de texto que se trata como valor único de entrega, y `telefono` guarda un solo número por fila.

**2FN:** `cantidad` y `precioUnitario` dependen de la clave completa `(idPedido, idProducto)`, porque son valores de un producto dentro de un pedido concreto. Se cumple.

### Notas de supuestos

- **Claves candidatas adicionales.** `placa` se trata como única (dos vehículos no comparten placa) y `(idDomiciliario, fechaHora)` como única (un domiciliario no está en dos posiciones al mismo instante). Ambas deben declararse `UNIQUE` en las migraciones.
- **N1 (`barrio -> ciudad`).** En el mundo real un barrio pertenece a una ciudad, lo que sugeriría una DF transitiva en `DIRECCION`. No se trata como DF del modelo porque los nombres de barrio no son únicos entre ciudades y el sistema no tiene un catálogo de barrios. Si se agregara ese catálogo, `ciudad` se movería allí.

## 3. Hallazgos que violan 3FN

### H1 — `PEDIDO.idCliente` es transitivamente dependiente

Cada dirección pertenece a un solo cliente, así que `idPedido -> idDireccion -> idCliente`. Al guardar también `idCliente` en `PEDIDO` se podría registrar un pedido del cliente A con la dirección del cliente B, y la base no lo detectaría.

**Decisión: excepción controlada.** Se conserva `idCliente` en `PEDIDO` porque el requisito R03 pide que cada pedido pertenezca a un cliente y casi todas las consultas filtran por cliente sin pasar por `DIRECCION`. La redundancia se protege de forma declarativa:

1. `UNIQUE (idDireccion, idCliente)` en `DIRECCION`.
2. Clave foránea compuesta `PEDIDO (idDireccion, idCliente) -> DIRECCION (idDireccion, idCliente)`.

Con eso la inconsistencia no se puede insertar. La alternativa de eliminar `PEDIDO.idCliente` también es válida, pero obliga a un JOIN adicional en cada consulta por cliente.

### H2 — `UBICACION.idDomiciliario` es transitivamente dependiente

Cuando el registro tiene servicio, `idServicio -> idDomiciliario` (un servicio tiene un solo domiciliario a la vez), así que `idDomiciliario` se puede derivar.

**Decisión: excepción controlada.** El dato se conserva porque un domiciliario puede reportar su posición **sin servicio activo** (por ejemplo, para que la central vea su ubicación al asignar, requisito R12). En ese caso `idServicio` es NULL y `idDomiciliario` no se puede derivar. Para evitar contradicciones cuando sí hay servicio:

1. `UNIQUE (idServicio, idDomiciliario)` en `SERVICIO_DOMICILIO`.
2. Clave foránea compuesta `UBICACION (idServicio, idDomiciliario) -> SERVICIO_DOMICILIO (idServicio, idDomiciliario)`. Con `MATCH SIMPLE` (el valor por defecto) la comprobación se omite cuando `idServicio` es NULL.

Esto requiere que `UBICACION.idServicio` admita NULL, lo cual no es así en el esquema de la Entrega 1 (ver sección 5).

## 4. Excepciones por dato histórico deliberado

| Id | Tabla / atributo | Por qué parece redundante | Justificación |
|---|---|---|---|
| E1 | `DETALLE_PEDIDO.precioUnitario` frente a `PRODUCTO.precio` | Parece repetir el precio del producto | `PRODUCTO.precio` es el precio **actual** y cambia con el tiempo. `precioUnitario` es el precio **al momento del pedido** y no se puede derivar después. No es una DF `idProducto -> precioUnitario`. Si se quitara, el historial de ingresos cambiaría cada vez que se modifica un precio. |
| E2 | `RUTA.destinoLatitud/Longitud` frente a las coordenadas de `DIRECCION` | El destino de entrega coincide con la dirección del pedido | Cada ruta es una consulta puntual y su destino puede ser el punto de recogida o el de entrega. Además, la dirección del cliente puede corregirse después y la ruta debe conservar lo que se consultó. Es un dato de cada consulta, no una dependencia de `idServicio`. |
| E3 | `SERVICIO_DOMICILIO.estadoServicio` frente a las fechas de recogida y entrega | El estado se puede inferir de qué fechas están registradas | No es una DF estricta: hay estados sin fecha asociada (asignado, cancelado). Se mantiene y se protege con un `CHECK` que relacione estado y fechas, por ejemplo `fechaEntrega IS NULL OR estadoServicio = 'ENTREGADO'`. |

## 5. Recomendaciones para las migraciones 

| Qué | Dónde | Razón |
|---|---|---|
| `UNIQUE (placa)` | `VEHICULO` | La placa es clave candidata (BCNF). |
| `UNIQUE (idDomiciliario, fechaHora)` | `UBICACION` | Clave candidata; evita posiciones duplicadas. |
| `UNIQUE (idDireccion, idCliente)` y FK compuesta | `DIRECCION` / `PEDIDO` | Protege la excepción H1. |
| `UNIQUE (idServicio, idDomiciliario)` y FK compuesta | `SERVICIO_DOMICILIO` / `UBICACION` | Protege la excepción H2. |
| `UBICACION.idServicio` admite NULL | `UBICACION` | Permite posiciones sin servicio activo (R12) y justifica H2. |
| `CHECK` de estados válidos | `PEDIDO`, `SERVICIO_DOMICILIO`, `DOMICILIARIO` | Hoy son `VARCHAR(120)` libres; la rúbrica los exige como `CHECK`. |


