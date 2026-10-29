# Verificación de equivalencia — TP Unidad 5, Parte D

Grupo E · 2026-10-15 · Script: `sql/usuario_anon.sql` (re-ejecutable,
verificado 2 veces seguidas con `ON_ERROR_STOP`).

## 1. Técnica aplicada

`usuario_anon` deriva 1:1 de `usuario` (`origen_id = id_usuario`): las
columnas de agrupación (`rol`, `created_at`, `eliminado`) se copian verbatim y
las identificatorias se sintetizan de forma determinista
(`Usuario_N`, `usuario_N@ejemplo.local`, unicidad de mails preservada).
`celular_usuario` y `contrasena_usuario` **no existen** en la tabla
anonimizada (eliminación, no enmascaramiento).

## 2. Consultas y resultados (ejecución real, 2026-10-14)

Agregación pedida con precisión a la IA —cantidad por rol y mes de alta— y su
equivalente sobre la tabla real, generada por la IA:

```sql
-- Sobre usuario_anon (especificación del equipo a la IA):
SELECT rol, date_trunc('month', created_at)::date AS mes_alta, count(*)
FROM usuario_anon GROUP BY rol, date_trunc('month', created_at) ORDER BY 1,2;
-- Equivalente sobre usuario (devuelta por la IA, mismo GROUP BY):
SELECT rol, date_trunc('month', created_at)::date AS mes_alta, count(*)
FROM usuario GROUP BY rol, date_trunc('month', created_at) ORDER BY 1,2;
```

| rol | mes_alta | `usuario_anon` | `usuario` (real) |
|---|---|---|---|
| ADMIN | 2026-10-01 | 1 | 1 |
| USUARIO | 2026-10-01 | 4 | 4 |

**Mismos conteos, mismos agrupamientos: equivalencia demostrada, no solo
afirmada.** La equivalencia vale por construcción para cualquier `GROUP BY`
sobre columnas copiadas verbatim; no valdría para búsquedas por nombre
(con `LIKE 'Jua%'` la anonimizada devuelve cero), límite documentado de la
técnica.

## 3. Qué nunca debe salir hacia una IA sin anonimizar (punto 4)

Nunca deben salir de Food Store hacia un asistente de IA los mails y
celulares de clientes (datos de contacto directos), los hashes de
`contrasena_usuario` (aun hasheados, habilitan ataques de diccionario y
revelan reutilización), ni el cruce fino nombre+apellido+fecha de alta que
permite re-identificar a una persona; todo ello debe pasar primero por
`usuario_anon` (o agregados equivalentes), porque un prompt con datos reales
queda fuera del control del equipo una vez enviado.
