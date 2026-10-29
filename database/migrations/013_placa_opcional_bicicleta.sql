-- 013_placa_opcional_bicicleta.sql
-- Correccion a 009: una bicicleta no tiene placa. En la Entrega 1 la placa era
-- nulable; aqui se restaura esa flexibilidad pero se mantiene la regla de negocio:
-- todo vehiculo motorizado (moto, carro) DEBE tener placa.
-- (UNIQUE permite varios NULL, asi que varias bicicletas no chocan.)
ALTER TABLE vehiculo ALTER COLUMN placa DROP NOT NULL;
ALTER TABLE vehiculo ADD CONSTRAINT ck_vehiculo_placa
    CHECK (tipo = 'bicicleta' OR placa IS NOT NULL);
