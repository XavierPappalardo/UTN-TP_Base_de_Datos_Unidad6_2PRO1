# Informe de incidente — TP Unidad 5, Parte C (simulacro controlado)

Grupo E: Gómez, Pappalardo, Reinoso, Ibáñez, Sisterna, Arroyo · 2026-10-15

> Todo lo aquí descrito se ejecutó **exclusivamente contra la instancia
> propia de desarrollo** (`food_store` local). Ninguna técnica se probó contra
> sistemas de terceros.

## 1. Script del simulacro y constancia del escalamiento

Script: `sql/simulacro_incidente.sql`, ejecutado como `app_web`
(credencial de la aplicación, simulando su compromiso) el 2026-10-14
22:22:47/-03, con `log_statement='all'` temporal solo para el laboratorio
(`ALTER DATABASE food_store SET/RESET log_statement`, verificado antes y
después). Secuencia: 4 × `fn_autenticar` fallido → 1 × exitoso → `count(*)`
+ lectura completa de columnas no sensibles de `usuario` → `GRANT admin_datos`
→ `fn_resetear_password` sobre otra cuenta.

**Constancia (punto 2): el escalamiento FALLA.** Salida real de psql:

```text
psql:simulacro_incidente.sql:45: ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
psql:simulacro_incidente.sql:49: ERROR:  permiso denegado a la función fn_resetear_password
```

No hay hallazgo correctivo: el esquema de la Parte A **resiste** (sin `GRANT`
amplio, sin `EXECUTE` reservado, sin lectura de secretos). Se continúa.

## 2. Reconstrucción pedida a la IA (punto 4 — respuesta completa)

Prompt enviado (sin contexto adicional, solo el log):

> *"Reconstruí qué ocurrió a partir de este log de PostgreSQL y proponé una
> hipótesis de contención. No cuento con información adicional: trabajá solo
> con lo que el log muestra."* + contenido de
> `docs/log_simulacro_anonimizado.txt`.

Respuesta completa de la IA:

> *"En 40 milisegundos (22:22:47.259 a 22:22:47.299/-03) una misma sesión
> (PID 11236, usuario `app_web`, origen 198.51.100.23, cliente `psql`) contra
> `food_store` ejecutó esta secuencia: (1) cinco llamadas a
> `fn_autenticar('usuario.03@ejemplo.local', …)` en 7 ms —las primeras cuatro
> fallaron y la quinta fue el inicio de sesión exitoso—; (2) un `count(*)` y
> un `SELECT` de todas las columnas no sensibles de `usuario`, es decir, un
> barrido completo del padrón (exfiltración del listado de usuarios); (3) un
> `GRANT admin_datos TO app_web`, intento de escalamiento de privilegios que
> el motor bloqueó (`se ha denegado el permiso`); (4) un
> `fn_resetear_password('usuario.07@ejemplo.local', …)` para tomar otra
> cuenta, también bloqueado (`permiso denegado a la función`). Cierra con
> desconexión de 0,053 s. Hipótesis: ataque externo automatizado desde
> 198.51.100.23 que comprometió la credencial de la app, enumeró usuarios e
> intentó escalar y pivotear. Contención propuesta: bloquear de inmediato el
> origen en `pg_hba.conf`/firewall, rotar la credencial de `app_web`, forzar
> el reseteo de `usuario.03`, y auditar sesiones concurrentes."*

## 3. Contraste crítico: IA vs. lo realmente ejecutado (punto 5)

| # | Dice la IA | Evidencia | Veredicto del equipo |
|---|---|---|---|
| 1 | Sesión única, mismo PID/usuario/origen, 40 ms, cliente psql, orden de pasos | Líneas 9–29 del log anonimizado | ✅ **Acertó.** La secuencia y los tiempos son exactos. |
| 2 | El escalamiento y el reseteo fueron **bloqueados** | `ERROR` + `SENTENCIA` en el log | ✅ **Acertó.** Coincide con la constancia del punto 1. |
| 3 | "Las primeras cuatro llamadas fallaron y la quinta fue exitosa" | El log registra las **llamadas**, no sus **valores de retorno** (`f/f/f/f/t` no aparecen en ningún lado) | ❌ **Afirmación que el log no sustenta.** Es una inferencia por posición, no evidencia. En la ejecución real sí hubo 4 fallos + 1 éxito, pero esa verdad viene del **script**, no del log. |
| 4 | "Exfiltración del listado de usuarios" | El log prueba que el `SELECT` **se ejecutó**, no que las filas **se devolvieron** (los resultados nunca quedan en el log) | ❌ **Afirmación que el log no sustenta.** Pudo haber devuelto 5 filas o fallar en el cliente; el log no lo dice. Lo correcto: "lectura ejecutada, exfiltración no confirmable". |
| 5 | "Ataque externo automatizado desde 198.51.100.23" | La IP estaba anonimizada (origen real: localhost de desarrollo) y 40 ms entre 9 sentencias sugiere script, no humano —pero nada de eso distingue ataque de prueba | ❌ **Causa asumida sin evidencia + dato anonimizado mal leído.** El log no permite atribuir intencionalidad (test vs. ataque); la atribución requiere contexto fuera del log. |
| 6 | Omite que `fn_autenticar` se ejecutó con privilegio mínimo intacto y que ni siquiera el barrido tocó secretos | El `SELECT` del barrido lista solo columnas no sensibles (sin mail/celular/hash) | ⚠️ **Omitió.** El log sí muestra las columnas pedidas: la IA no destacó que el mínimo privilegio acotó el impacto, que es el dato más relevante para contención. |
| 7 | Omite la ventana de `log_statement='all'` temporal | Visible solo en el log completo (no en el fragmento entregado) | ⚠️ **Omitió (correctamente).** Con solo el fragmento no podía saberlo; confirma que reconstruir con el fragmento recortado pierde el marco. |

**Conclusión del contraste:** la IA reconstruye bien *qué sentencias, en qué
orden, con qué resultado de permiso*, pero inventa *resultados de negocio*
(¿qué devolvió cada función?), *volúmenes* (¿cuántos datos salieron?) e
*intencionalidad* (¿ataque o prueba?). Las tres son exactamente las preguntas
que un log nativo no responde —y las tres son las que deciden la contención.

## 4. Decisión final de contención del equipo (punto 6)

Ante un caso real con esta evidencia, el equipo haría —**decisión humana
tomada a partir de evidencia, no acción automática sugerida por la IA**:

1. **Preservar evidencia** antes de tocar nada: copia inmutable del log y de
   `pg_stat_activity` de esa ventana.
2. **Bloquear el origen** a nivel `pg_hba.conf` + firewall (temporal y
   reversible), sin dar de baja el servicio para el resto.
3. **Rotar la credencial de `app_web`** de inmediato y forzar el reseteo de
   la contraseña de `usuario.03` (cuenta tanteada), aunque el log no pruebe
   que el tanteo tuvo éxito: ante duda razonable, se rota.
4. **Verificar que no hubo escalamiento lateral:** `SELECT * FROM
   information_schema.role_table_grants WHERE grantee='app_web'` y
   membresías (`\du`), comparadas contra `docs/verificacion_roles.txt`.
5. **Endurecer `fn_autenticar`** (demora progresiva + bloqueo tras N fallos +
   alerta), porque el log demostró que 5 intentos en 7 ms no generan ninguna
   señal con la configuración actual.
6. **No bloquear automáticamente** por sugerencia de la IA: su hipótesis de
   "ataque externo" era infundada (era localhost anonimizado); una acción
   automática habría bloqueado una IP\[
...[truncated 208 chars]
