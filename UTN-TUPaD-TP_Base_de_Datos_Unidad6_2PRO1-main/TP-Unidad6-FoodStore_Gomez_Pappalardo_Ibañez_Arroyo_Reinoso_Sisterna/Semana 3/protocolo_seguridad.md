# Protocolo de Seguridad - Base de Datos Food Store

Este documento establece el procedimiento estándar de tres pasos obligatorios exigidos por la cátedra para aplicar cualquier script o cambio sobre la base de datos.

---

## 1️ Copia (Base de Desarrollo)

Para aislar las pruebas y no arriesgar los datos reales, se clona la base de datos principal directamente desde el editor SQL de DBeaver.

### Comando a ejecutar en DBeaver:

```sql
CREATE DATABASE copia_trabajo WITH TEMPLATE food_store;
```

---

## 2️ Transacción (Inspección Segura)

Todo script que escriba o modifique datos (INSERT, UPDATE, DELETE) debe ejecutarse en DBeaver dentro de un bloque seguro para visualizar las filas afectadas antes de confirmar el cambio.

### Flujo de ejecución en DBeaver:

```sql
BEGIN;

-- Pegar aquí el script a evaluar
UPDATE articulo SET valor = 2000 WHERE id = 1;

-- Verificar visualmente los cambios 
SELECT * FROM articulo WHERE id = 1;

-- Deshacer el cambio para asegurar la integridad
ROLLBACK;
```

Solo si el resultado validado en DBeaver es exactamente el esperado, se vuelve a ejecutar reemplazando `ROLLBACK;` por `COMMIT;`.

---

## 3️ Respaldo (Antes de cambios DDL)

Si se requiere modificar la estructura de las tablas (ALTER TABLE, DROP, CREATE), el ROLLBACK no protege los datos. Se debe generar un respaldo físico desde la terminal de Windows (PowerShell) antes de operar.

### Comando a ejecutar en PowerShell:

```powershell
pg_dump -U postgres -d copia_trabajo -f backup_food_store.sql
```

Si el cambio estructural corrompe la base, este archivo permite restaurar la copia de trabajo a su estado original.