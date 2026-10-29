# spec: indice descartado (sobreindexación)

Objetivo: registrar la propuesta de la IA que se RECHAZA explícitamente.

Propuesta descartada 1 (principal):
CREATE INDEX idx_producto_disponible ON producto (disponible);
Motivo: `disponible` es BOOLEAN (cardinalidad 2). Sin condición parcial muy
selectiva, el planificador prefiere Seq Scan; el índice solo suma costo de
mantenimiento en cada INSERT/UPDATE sin mejorar lecturas. Sobreindexación típica.

Propuesta descartada 2 (alternativa redundante):
CREATE INDEX idx_pedido_usuario ON pedido (usuario_id);
Motivo: redundante con idx_pedido_usuario_id ya creado en la Semana 3 sobre la
misma columna. Un segundo índice duplica el costo de escritura sin cambiar ningún plan.

Criterio de aceptación del descarte: justificación escrita en
informe_mediciones.md §A5 y en duia.md (fila 3), y ausencia de estas sentencias
en indices.sql. La decisión no se delega a la IA.
