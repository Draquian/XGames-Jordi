# Navidad de Jordi — Fase 1 + 2 + 3 + 4 + 5

Marcador de minijocs per a una festa, sense Internet, sense servidors
externs i sense núvol. Aquest paquet conté el codi Dart/Flutter
complet fins a la **Fase 5**: tot el que ja tenies (base de dades
local, comunicació WiFi, incorporació per QR, gestió de minijocs,
jugar-los de veritat, classificació i historial) més **el final de la
partida i el podi**. Amb aquesta fase, l'app cobreix ja tot el flux
complet descrit a l'encàrrec original.

## Què fa ja aquesta versió (de veritat, no és una maqueta)

De la Fase 1:
- El màster crea una sessió, es genera un codi QR i un codi curt.
- Els jugadors s'uneixen escanejant el QR (o introduint el codi a mà) i
  triant un nom.
- El màster veu en temps real qui s'ha unit, i pot expulsar algú.
- Reconnexió automàtica (jugador o màster) si es tanca l'app o el
  mòbil es reinicia, sense duplicar jugadors.
- Tot funciona per WiFi local (router de la festa o punt d'accés
  personal del màster).

De la Fase 2:
- El màster crea minijocs des de la pantalla "Minijocs": nom,
  descripció, normes i el seu propi sistema de puntuació (posicions
  exactes, punts positius o negatius, i una regla especial opcional
  per a "qui quedi últim/a").
- Els minijocs es poden editar en qualsevol moment.

De la Fase 3:
- El màster pot pitjar **"Començar"** en un minijoc pendent: tots els
  jugadors ho veuen a l'instant i la seva pantalla canvia per mostrar
  el nom, la descripció i les normes del minijoc actiu. Només es pot
  tenir un minijoc en curs alhora.
- El màster pitja **"Finalitzar minijoc"** i introdueix la posició de
  cada jugador (deixar en blanc = no hi ha jugat; dues persones amb la
  mateixa posició = empat, decidit manualment). Els punts es calculen
  sols segons les regles d'aquell minijoc.
- El màster pot tornar a obrir un minijoc ja finalitzat ("Veure
  resultats") i corregir-hi les posicions si cal.

De la Fase 4:
- Pantalla **"Classificació"** pel màster: TOTS els jugadors (també
  els desconnectats i els expulsats, que mantenen els seus punts)
  ordenats de més a menys punts.
- Historial complet per jugador, i **ajustaments manuals de punts**
  (positius o negatius, amb motiu) fora del flux normal d'un minijoc.
- Pantalla **"Els meus resultats"** pel jugador, amb el seu total i
  tot el seu historial.

Nou a la Fase 5:
- Botó **"Finalitzar la partida"** al lobby del màster (amb
  confirmació). Queda bloquejat mentre hi hagi un minijoc en curs —
  cal finalitzar-lo primer.
- En finalitzar, la sessió es tanca automàticament a noves
  incorporacions i **tots els jugadors veuen a l'instant el podi
  final**: 🥇🥈🥉 per als tres primers i la resta ordenats a sota, amb
  la puntuació de cadascú. Si hi ha menys de tres jugadors, el podi
  s'adapta sol (només mostra les medalles que calen).
- El màster també veu el mateix podi, i pot seguir consultant la
  classificació i l'historial complet després d'acabar.
- Si un jugador es reconnecta després que la partida hagi acabat,
  també veu directament el podi final (no cal que hi fos en aquell
  moment).
- Per desempatar el podi si cal, el màster pot fer servir l'eina
  d'ajustaments manuals de la Fase 4 abans de finalitzar la partida.

## Què queda per a properes fases

- Fase 6 (opcional): fusió manual d'un dispositiu reconnectat amb un
  jugador existent (ara mateix la reconnexió automàtica per
  dispositiu ja cobreix el cas normal), i descobriment automàtic per
  WiFi (mDNS/Bonjour) com a alternativa a escanejar el QR.


## 1. Requisits

- Flutter instal·lat (canal *stable*): https://docs.flutter.dev/get-started/install
- Un editor (VS Code o Android Studio) amb el plugin de Flutter.
- Per provar-ho de veritat: **dos mòbils** (o un mòbil + un emulador),
  Android i/o iOS.

Comprova que tot està bé instal·lat:

```bash
flutter doctor
```

## 2. Crear el projecte base

Aquest paquet només conté el codi Dart (`lib/`) i el `pubspec.yaml`:
li falten les carpetes natives `android/` i `ios/`, que Flutter genera
ell mateix. Per muntar-ho tot:

```bash
# 1. Descomprimeix aquest zip, per exemple a ~/dev/navidad_de_jordi_codi

# 2. Crea un projecte Flutter nou amb el mateix nom, en una carpeta a part
flutter create --org com.tuempresa navidad_de_jordi
cd navidad_de_jordi

# 3. Substitueix el pubspec.yaml generat pel d'aquest paquet
cp ~/dev/navidad_de_jordi_codi/pubspec.yaml ./pubspec.yaml

# 4. Substitueix la carpeta lib/ generada per la d'aquest paquet
rm -rf lib
cp -r ~/dev/navidad_de_jordi_codi/lib ./lib

# 5. Copia també l'analysis_options.yaml
cp ~/dev/navidad_de_jordi_codi/analysis_options.yaml ./analysis_options.yaml
```

Ara ja tens un projecte Flutter complet, amb `android/` i `ios/`
generats per l'eina oficial.

## 3. Permisos necessaris

### Android — `android/app/src/main/AndroidManifest.xml`

Afegeix aquests permisos DINS de `<manifest>`, abans de `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS — `ios/Runner/Info.plist`

Afegeix aquestes claus DINS del `<dict>` principal:

```xml
<key>NSCameraUsageDescription</key>
<string>Es fa servir la càmera per escanejar el codi QR de la partida.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Cal accedir a la xarxa local per connectar el mòbil amb el
dispositiu del màster, sense passar per Internet.</string>
<key>NSBonjourServices</key>
<array>
  <string>_navidaddejordi._tcp</string>
</array>
```

iOS demanarà aquest permís de xarxa local la primera vegada que
l'app ho necessiti: si es rebutja per error, cal reactivar-lo a
Ajustos > Privadesa i seguretat > Xarxa local.

## 4. Instal·lar dependències i executar

```bash
flutter pub get
flutter devices        # per veure els dispositius/emuladors disponibles
flutter run             # tria el dispositiu quan ho demani
```

Per provar el flux complet fan falta com a mínim dos dispositius (o un
dispositiu + un emulador/simulador) executant l'app alhora: un fent de
màster i l'altre unint-se com a jugador. **Els emuladors/simuladors no
sempre tenen accés real a la xarxa WiFi del teu ordinador**, així que
per provar la part de connexió és més fiable fer servir mòbils
físics connectats a la mateixa xarxa (o al punt d'accés personal
d'un d'ells).

## 5. Estructura del projecte

```
lib/
  main.dart                       Arrencada de l'app
  core/
    app_theme.dart                Tema visual senzill
  data/
    models/                       Jugador, sessió, minijoc, resultat, ajustament
    local/
      master_database.dart        SQLite del MÀSTER (font única de veritat)
      device_identity.dart        Identificador persistent del dispositiu
      player_cache.dart           Caché lleugera del JUGADOR
  network/
    protocol.dart                 Tipus de missatge WebSocket
    connection_info.dart          Contingut del QR + IP local
    master_server.dart            Servidor local (WebSocket) del màster
    player_client.dart            Client WebSocket del jugador, amb reconnexió
  state/
    master_state.dart             Estat de l'app per al dispositiu del màster
    player_state.dart             Estat de l'app per al dispositiu del jugador
  features/
    role_select_screen.dart       Pantalla inicial (màster / jugador)
    master/
      master_home_screen.dart     Crear sessió
      master_lobby_screen.dart    QR + llista de jugadors en directe
      minigame_list_screen.dart   Llista de minijocs de la sessió
      minigame_editor_screen.dart Crear/editar un minijoc i la seva puntuació
      minigame_results_screen.dart Introduir/corregir posicions i punts
      ranking_screen.dart          Classificació general de tots els jugadors
      player_history_screen.dart  Historial d'un jugador + ajustaments manuals
      final_podium_screen.dart    Podi final (vista del màster)
    player/
      player_join_screen.dart     Escanejar QR / codi manual + nom
      player_lobby_screen.dart    Sala d'espera + minijoc actiu + podi final
      minigame_active_section.dart Vista del minijoc en curs
      my_stats_screen.dart        Total i historial complet del jugador
      qr_scan_screen.dart         Escàner de QR
    shared/
      reconnecting_banner.dart    Avís de reconnexió
      podium_view.dart            Podi 🥇🥈🥉 compartit entre màster i jugador
```

## 6. Com continuem

Amb aquesta fase, l'app cobreix ja tot el flux principal de
l'encàrrec original. El que queda és la Fase 6, opcional i de
"polit": una eina perquè el màster fusioni manualment un dispositiu
reconnectat amb un jugador ja existent quan la reconnexió automàtica
per `deviceId` no n'hi ha prou (algú ha reinstal·lat l'app o canviat
de mòbil), i el descobriment automàtic per WiFi (mDNS/Bonjour) com a
alternativa a escanejar el QR quan tots dos dispositius ja són a la
mateixa xarxa.

