# Día 02 · Pictogram

<img src="grafico.png" alt="Versión editorial final del Titanic" width="350"/>


<br>

## Pregunta

Cómo de llenos salieron los botes salvavidas del Titanic a medida que avanzaba la noche del hundimiento.

## Gráfico

Pictograma construido íntegramente en R, representado como una escena nocturna.

El eje horizontal muestra la cronología estimada de la evacuación. Cada bote es una columna situada sobre la superficie del mar, formada por figuras humanas apiladas en filas de dos.

- **Figuras:** ocupantes por categoría y plazas vacías.

- **Colores:** tripulación, hombres, mujeres y plazas sin ocupar.

- **Raya horizontal:** capacidad nominal del bote.

- **Porcentajes bajo el agua:** ocupación de tres botes destacados.

- **Eje izquierdo:** capacidades de los tres tipos de bote.

El Titanic hundiéndose, dibujado mediante polígonos en R, cierra la secuencia temporal.

## Datos

Ocupantes y capacidad de los 18 botes que se arriaron, con su hora de salida, según el informe británico sobre el hundimiento (Mersey, 1912). Los recoge Michael Friendly en el paquete `vcd` como `Lifeboats`. Los tipos de bote (catorce de 65 plazas, dos de emergencia de 40 y cuatro plegables de 47) están documentados en fuentes como [Encyclopedia Titanica](https://www.encyclopedia-titanica.org/titanic-lifeboat-occupancy-totals.html).

## Proceso de diseño

Esta visualización se desarrolló mediante un proceso iterativo de diseño editorial y programación asistida por IA.

La conceptualización, selección de datos, narrativa y decisiones visuales son propias. Claude se utilizó como asistente de implementación en R, con revisión y modificaciones directas del código.

[**Ver el proceso completo**](proceso.md)**.**

## Validaciones

Se han definido tres comprobaciones ejecutables en R mediante `stopifnot()`, orientadas a verificar la consistencia de los datos y su representación.

| Validación | Qué comprueba |
|----|----|
| Integridad de los datos | 18 botes únicos, ausencia de valores nulos relevantes, capacidades válidas y consistencia entre ocupantes y categorías. |
| Fidelidad de los pictogramas | Que cada bote represente el número correcto de ocupantes y plazas vacías, incluidos los casos de sobreocupación declarada. |
| Consistencia editorial | Que los grupos cronológicos contengan 6 y 12 botes y que sus porcentajes calculados correspondan al 54 % y 91 % utilizados en la narrativa. |

Estas comprobaciones permiten detectar inconsistencias en el procesamiento y la representación. No garantizan la exactitud histórica de los testimonios originales.

## Limitaciones

Las cifras del informe suman 854 ocupantes, más que los cerca de 710 supervivientes, así que sobreestiman la ocupación y en realidad hubo más plazas vacías. Por eso tres botes, el 11, el 15 y el C, aparecen por encima de su capacidad. Las mujeres incluyen a las tripulantes. Los botes que salieron a la misma hora se separan uno o dos minutos para que no se monten. Faltan los plegables A y B, que no llegaron a arriarse con normalidad.

## Lo que aprendí

- La metáfora visual también comunica, el mar, los botes y el Titanic permiten construir una escena reconocible sin abandonar la representación cuantitativa.
- La oscuridad refuerza el contexto nocturno y hace que las plazas vacías se integren visualmente en la escena.
- R permite construir composiciones editoriales completas. La combinación de pictogramas, polígonos, anotaciones y tipografía personalizada permite ir más allá de los gráficos convencionales.
- La gestión de tipografías mejora la reproducibilidad. Guardar las fuentes en el proyecto y registrarlas con systemfonts favorece resultados consistentes entre equipos. Las fuentes con licencia OFL pueden distribuirse respetando las condiciones de su licencia.

## Difusión

Pendiente.
