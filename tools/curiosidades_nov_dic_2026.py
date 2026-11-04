#!/usr/bin/env python3
"""Genera docs/curiosidades.json con una curiosidad por día (4 nov - 31 dic 2026)."""
import json
from datetime import date, timedelta
from pathlib import Path

C = [
    ("Espacio", "Días más largos que años", "Venus tarda unos 243 días terrestres en girar sobre sí misma y solo 225 en dar la vuelta al Sol: su día dura más que su año."),
    ("Animales", "Tres corazones", "Los pulpos tienen tres corazones y sangre azul, porque transportan el oxígeno con hemocianina, que lleva cobre en lugar de hierro."),
    ("Historia", "La torre provisional", "La Torre Eiffel se levantó para la Exposición Universal de 1889 y debía desmontarse a los 20 años. La salvó su uso como antena de radio."),
    ("Valencia", "La Lonja", "La Lonja de la Seda de Valencia, gótico civil del siglo XV, es Patrimonio de la Humanidad desde 1996."),
    ("Cuerpo", "Huesos que se fusionan", "Un adulto tiene 206 huesos, pero un bebé nace con unos 300: muchos se van fusionando al crecer."),
    ("Espacio", "Luz con retraso", "La luz del Sol tarda unos 8 minutos y 20 segundos en llegar a la Tierra: siempre lo ves como era hace 8 minutos."),
    ("Lenguaje", "Las cinco vocales", "«Murciélago» contiene las cinco vocales. «Euforia» también, y solo tiene siete letras."),
    ("Animales", "Rosa por lo que comen", "Los flamencos son rosas por los carotenoides de las algas y los pequeños crustáceos que comen. Sin ellos se vuelven blanquecinos."),
    ("Historia", "La guerra más corta", "La guerra anglo-zanzibariana de 1896 duró menos de una hora. Es la guerra más corta registrada."),
    ("Espacio", "Huellas eternas", "Las huellas de los astronautas en la Luna pueden durar millones de años: allí no hay viento ni lluvia que las borre."),
    ("Comida", "La miel no caduca", "La miel bien cerrada prácticamente no se estropea: se ha encontrado miel comestible en tumbas del antiguo Egipto."),
    ("Valencia", "Tribunal de las Aguas", "Cada jueves a mediodía el Tribunal de las Aguas se reúne en la puerta de los Apóstoles de la Catedral. Es Patrimonio Inmaterial de la UNESCO."),
    ("Ciencia", "Efecto Mpemba", "En ciertas condiciones el agua caliente puede congelarse antes que la fría. Se llama efecto Mpemba y los científicos aún lo debaten."),
    ("Animales", "Dormilones", "Los koalas duermen entre 18 y 22 horas al día: su dieta de eucalipto les da muy poca energía."),
    ("Tecnología", "El primer SMS", "El primer SMS se envió en diciembre de 1992 desde un ordenador a un móvil y decía «Merry Christmas»."),
    ("Cuerpo", "100.000 latidos", "Tu corazón late unas 100.000 veces al día: más de 2.500 millones de veces a lo largo de una vida."),
    ("Geografía", "Más ancha que la Luna", "Australia mide unos 4.000 km de este a oeste; la Luna tiene unos 3.474 km de diámetro."),
    ("Historia", "Cleopatra y la Luna", "Cleopatra vivió más cerca en el tiempo de la llegada a la Luna que de la construcción de la Gran Pirámide de Guiza."),
    ("Deporte", "42,195 km", "La maratón mide 42,195 km desde los Juegos de Londres 1908, cuando se alargó para que acabara frente al palco real."),
    ("Animales", "Mejores amigas", "Las vacas forman vínculos: un estudio vio que se estresan menos cuando están con su compañera preferida."),
    ("Espacio", "Más que arena", "Se estima que en el universo observable hay más estrellas que granos de arena en todas las playas de la Tierra."),
    ("Lenguaje", "Robot", "«Robot» viene del checo «robota», trabajo forzado. Se usó por primera vez en la obra de teatro R.U.R. de Karel Čapek, en 1920."),
    ("Ciencia", "Plátanos radiactivos", "Los plátanos son un poco radiactivos por su potasio-40. Harían falta millones para que fuera peligroso."),
    ("Valencia", "Arroz de la Albufera", "El cultivo de arroz en la Albufera viene de época musulmana. Sin esos arrozales no existiría la paella."),
    ("Animales", "Marcha atrás", "Los colibríes son las únicas aves capaces de volar hacia atrás de forma sostenida."),
    ("Historia", "Vikingos sin cuernos", "Los vikingos no llevaban cascos con cuernos: es una imagen del siglo XIX que popularizó la ópera."),
    ("Cuerpo", "Uñas a dos velocidades", "Las uñas de las manos crecen bastante más rápido que las de los pies."),
    ("Espacio", "El rey de las lunas", "Saturno es el planeta con más lunas conocidas: más de 140, y siguen apareciendo nuevas."),
    ("Tecnología", "El primer bug", "En 1947 se encontró una polilla atrapada en el ordenador Harvard Mark II. Se pegó en el cuaderno como el primer «bug» documentado."),
    ("Animales", "Dormir de la mano", "Las nutrias marinas a veces duermen agarradas de las patas para que la corriente no las separe."),
    ("Geografía", "Once horas", "Rusia tiene 11 husos horarios: cuando en Kaliningrado es mediodía, en Kamchatka ya son las diez de la noche."),
    ("Ciencia", "Más caliente que el Sol", "Un rayo puede calentar el aire a unos 30.000 °C, unas cinco veces la temperatura de la superficie del Sol."),
    ("Valencia", "Maratón rápida", "La Maratón de Valencia es una de las más rápidas del mundo por su recorrido llano y el clima suave de diciembre."),
    ("Historia", "Napoleón no era bajito", "Napoleón medía alrededor de 1,69 m, normal para su época. El mito viene de confundir pulgadas francesas e inglesas."),
    ("Animales", "Buceadores", "Los pingüinos emperador pueden bucear a más de 500 metros de profundidad y aguantar más de 20 minutos."),
    ("Lenguaje", "De dónde viene OK", "«OK» se popularizó en Boston en 1839 como broma: abreviatura de «oll korrect», una forma mal escrita de «all correct»."),
    ("Cuerpo", "Brillamos", "El cuerpo humano emite una luz muy débil por reacciones químicas de las células, pero es mil veces menos de lo que el ojo puede ver."),
    ("Espacio", "16 amaneceres", "La Estación Espacial da una vuelta a la Tierra cada 90 minutos: su tripulación ve unos 16 amaneceres al día."),
    ("Ciencia", "El vidrio no fluye", "Las vidrieras antiguas son más gruesas abajo por cómo se fabricaban, no porque el vidrio fluya como un líquido."),
    ("Animales", "Siete vértebras", "Las jirafas tienen siete vértebras en el cuello, las mismas que tú. Eso sí, cada una mide hasta 25 cm."),
    ("Valencia", "Universidad de 1499", "La Universitat de València se fundó en 1499. Es una de las universidades más antiguas de España."),
    ("Tecnología", "Códigos QR", "El código QR lo inventó en 1994 la empresa japonesa Denso Wave para seguir piezas en las fábricas de coches."),
    ("Geografía", "El punto más bajo", "La orilla del mar Muerto está a más de 400 m bajo el nivel del mar: es el punto más bajo de tierra firme."),
    ("Animales", "Cuervos rencorosos", "Los cuervos reconocen caras humanas y recuerdan durante años a quien los molestó. Incluso avisan a otros cuervos."),
    ("Espacio", "Descubierto con lápiz", "Neptuno se descubrió en 1846 gracias a cálculos matemáticos antes de verlo: se buscó donde decían las cuentas y allí estaba."),
    ("Cuerpo", "Olores y recuerdos", "El olfato está muy conectado con las zonas del cerebro de la memoria y las emociones: por eso un olor te transporta a otra época."),
    ("Comida", "Bayas por sorpresa", "En botánica, la fresa no es una baya, pero el plátano, el tomate y la berenjena sí lo son."),
    ("Espacio", "Solsticio", "Hoy es el solsticio de invierno: la noche más larga del año en el hemisferio norte. Desde mañana los días crecen."),
    ("Historia", "El Gordo", "El Sorteo de Navidad se celebra desde 1812, cuando se creó en Cádiz. Es una de las loterías más antiguas del mundo."),
    ("Animales", "Visión ultravioleta", "Los renos ven la luz ultravioleta, algo muy útil para distinguir líquenes y depredadores en la nieve del Ártico."),
    ("Historia", "Tregua de Navidad", "En la Navidad de 1914, soldados británicos y alemanes dejaron de luchar en varios puntos del frente y salieron a saludarse."),
    ("Espacio", "Villancico en órbita", "«Jingle Bells» fue la primera canción tocada en el espacio: en 1965, con una armónica a bordo de la Gemini 6."),
    ("Ciencia", "Seis brazos", "Los copos de nieve casi siempre tienen seis brazos por la estructura hexagonal del hielo, pero no hay dos iguales."),
    ("Animales", "Un corazón enorme", "El corazón de una ballena azul puede pesar unos 180 kg y su latido se detecta a kilómetros bajo el agua."),
    ("Historia", "Santos Inocentes", "El Día de los Inocentes recuerda la matanza de niños que, según el Evangelio, ordenó Herodes. Con los siglos se convirtió en día de bromas."),
    ("Geografía", "País de lagos", "Canadá tiene más lagos que el resto del mundo junto: alrededor del 60 % de los lagos del planeta."),
    ("Tecnología", "La primera web", "La primera página web de la historia, creada por Tim Berners-Lee en el CERN, sigue en línea en info.cern.ch."),
    ("Tradición", "Las doce uvas", "Las uvas de Nochevieja se popularizaron a principios del siglo XX. Una explicación habla de un excedente de uva en 1909."),
]

start = date(2026, 11, 4)
items = []
for i, (tema, titulo, texto) in enumerate(C):
    d = start + timedelta(days=i)
    items.append({"fecha": d.isoformat(), "tema": tema, "titulo": titulo, "texto": texto})
assert items[-1]["fecha"] == "2026-12-31", items[-1]["fecha"]
out = Path(__file__).resolve().parent.parent / "docs" / "curiosidades.json"
out.write_text(json.dumps({"actualizado": "2026-11-04", "curiosidades": items}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(len(items), "curiosidades")
