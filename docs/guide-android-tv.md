# Mode d'emploi : patcher une app sur Android TV (ADB à distance)

Ce guide part d'une app installée sur votre téléviseur ou boîtier (Android TV, Google TV, Fire TV)
et va jusqu'à la version patchée réinstallée dessus, **sans câble** : tout passe par ADB sur le
réseau local. Toutes les commandes se lancent depuis la racine du dépôt, sur votre ordinateur.

```
 TV ──(adb pull)──▶ samples/ ──(fusion)──▶ merged.apk ──(patch)──▶ out/*-patched.apk ──(adb install)──▶ TV
```

## 0. Prérequis sur l'ordinateur

- JDK 17+, Python 3, bash 4+ (macOS : `brew install bash`)
- `adb` (Android platform-tools) : `sudo apt install adb`, `brew install android-platform-tools`,
  ou le zip officiel de Google
- Les outils du dépôt :
  ```bash
  scripts/setup-tools.sh          # apktool, jadx, revanced-cli, APKEditor, uber-apk-signer
  ./gradlew build                 # bundle de patchs (token GitHub requis, voir README)
  ```
- L'ordinateur et la TV sur le **même réseau local**.

## 1. Quel paquet pour quel service ?

| Service | Paquet sur TV | Patch | État sur TV |
|---|---|---|---|
| Disney+ | `com.disney.disneyplus` | Disable ad pipeline | même APK que sur mobile : le patch s'applique tel quel |
| HBO Max | `com.wbd.stream` (Play Store ou Amazon Appstore) | Disable client-side ad strategy, Allow seeking past ads | nécessite les *targets* de votre version (voir `services/hbomax/`) |
| Netflix | `com.netflix.ninja` | Disable pause ads | nécessite les *targets* ; une grande partie de l'interface TV n'est pas du code Java (voir l'analyse) |
| Prime Video | `com.amazon.amazonvideo.livingroom` (Android TV) | Skip ads | **pas encore analysé** : le patch vise l'app mobile, il échouera proprement si le code diffère |
| Prime Video (Fire TV) | `com.amazon.firebat` | – | app système, non remplaçable sans root |

> **Applis préinstallées.** Sur beaucoup de téléviseurs, Netflix (et parfois Prime Video) est
> une **app système** livrée par le fabricant. Elle ne peut pas être désinstallée sans root, et
> une version re-signée ne peut pas s'installer par-dessus. Vérifiez à l'étape 3 avant d'aller plus
> loin.

## 2. Activer ADB sur la TV

### Android TV / Google TV

1. **Paramètres > Système > À propos** (sur certains modèles : *Préférences de l'appareil > À propos*).
2. Appuyez **7 fois** sur **Build** (*Version du build*) jusqu'au message « Vous êtes développeur ».
3. Revenez dans **Paramètres > Système > Options pour les développeurs** et activez :
   - **Débogage USB** (nécessaire même sans câble sur la plupart des modèles) ;
   - **Débogage sans fil** (Android TV 11+ / Google TV) ou **Débogage ADB réseau** selon le fabricant.
4. Notez l'adresse IP de la TV : **Paramètres > Réseau et Internet > (votre Wi-Fi)**.

### Fire TV

1. **Paramètres > Ma Fire TV > À propos** : appuyez 7 fois sur le nom de l'appareil.
2. **Paramètres > Ma Fire TV > Options pour les développeurs** : activez **Débogage ADB** et
   **Applis de sources inconnues** (ou *Installer des applis inconnues*).
3. IP : **Paramètres > Ma Fire TV > À propos > Réseau**.

## 3. Se connecter en ADB à distance

**Cas classique (port 5555)** – la plupart des Android TV et toutes les Fire TV :

```bash
adb connect 192.168.1.50:5555
```

La première fois, la TV affiche **« Autoriser le débogage ? »** : cochez *Toujours autoriser
depuis cet ordinateur* puis **OK**. Si la commande répond `unauthorized` ou `failed to
authenticate`, validez la boîte de dialogue puis relancez `adb connect`.

**Débogage sans fil avec appairage (Google TV, Android TV 11+)** – si le port 5555 ne répond pas :

1. Sur la TV : *Options pour les développeurs > Débogage sans fil > Associer l'appareil avec un
   code*. L'écran affiche une IP:port d'appairage et un code à 6 chiffres.
2. Sur l'ordinateur :
   ```bash
   adb pair 192.168.1.50:37123        # IP:port d'APPAIRAGE affiché, puis saisir le code
   adb connect 192.168.1.50:41235     # IP:port de CONNEXION affiché sur l'écran « Débogage sans fil »
   ```
   Les deux ports sont différents, et le port de connexion change à chaque redémarrage.

**Vérifier :**

```bash
adb devices                                         # la TV doit apparaître comme "device"
adb shell pm list packages | grep -E 'netflix|disney|wbd|amazon'
adb shell pm list packages -s | grep <paquet>       # si une ligne sort : app système, voir l'encadré §1
```

**Plusieurs appareils branchés ?** Indiquez la cible à toutes les commandes (et aux scripts du
dépôt) avec une variable d'environnement :

```bash
export ANDROID_SERIAL=192.168.1.50:5555
```

> **Sécurité.** ADB réseau donne un contrôle total de la TV. Ne l'exposez **jamais** sur Internet
> (pas de redirection du port 5555 sur la box). Pour travailler hors de chez vous, passez par un
> VPN vers votre réseau (WireGuard, Tailscale…) puis `adb connect` sur l'IP locale. Désactivez le
> débogage quand vous avez fini.

## 4. Récupérer l'APK

```bash
scripts/pull-apk.sh disneyplus              # détecte le paquet installé parmi ceux connus
scripts/pull-apk.sh netflix com.netflix.ninja   # ou précisez le paquet
```

Résultat : `samples/<service>/<paquet>-<version>/` avec `base.apk`, éventuellement des
`split_*.apk`, et `SOURCE.txt` (modèle de TV, date).

Équivalent manuel, pour comprendre ce que fait le script :

```bash
adb shell pm path com.disney.disneyplus
# package:/data/app/~~xxx/com.disney.disneyplus-yyy/base.apk
# package:/data/app/~~xxx/com.disney.disneyplus-yyy/split_config.armeabi_v7a.apk
# package:/data/app/~~xxx/com.disney.disneyplus-yyy/split_config.xhdpi.apk
adb pull /data/app/~~xxx/com.disney.disneyplus-yyy/base.apk
```

Récupérer l'APK **depuis la TV elle-même** garantit la bonne architecture (souvent
`armeabi-v7a` sur TV, même avec un processeur 64 bits) et les bonnes ressources d'écran.

## 5. Fusionner les splits

S'il y a des `split_*.apk`, fusionnez-les en un seul APK :

```bash
scripts/merge-splits.sh samples/disneyplus/com.disney.disneyplus-<version>
# -> samples/disneyplus/com.disney.disneyplus-<version>/merged.apk
```

S'il n'y a qu'un `base.apk`, utilisez-le directement à l'étape suivante.

## 6. Patcher

**Disney+** (aucune préparation) :

```bash
scripts/patch-with-cli.sh samples/disneyplus/com.disney.disneyplus-<version>/merged.apk \
  --exclusive -e "Disable ad pipeline"
```

**HBO Max** (avec les fichiers *targets* de votre version, voir `services/hbomax/README.md`) :

```bash
services/hbomax/scripts/patch-hbomax.sh samples/hbomax/com.wbd.stream-<version>/merged.apk \
  services/hbomax/targets/com.wbd.stream-<version>
```

**Netflix** (avec le fichier *targets* de votre version) :

```bash
VAF_PATCH="Disable pause ads" VAF_TARGETS=services/netflix/targets/com.netflix.ninja-<version>.txt \
  scripts/patch-with-cli.sh samples/netflix/com.netflix.ninja-<version>/merged.apk
```

**Prime Video (Android TV)** : expérimental. Le patch est déclaré pour l'app mobile, donc
ReVanced CLI l'ignore sur un autre paquet sauf avec `--force`. S'il ne trouve pas le code visé, il
échoue proprement ; dans ce cas, suivez `services/primevideo/analysis/skip-ads.md` pour analyser
cette version.

```bash
services/primevideo/scripts/patch-vodadsfree.sh \
  samples/primevideo/com.amazon.amazonvideo.livingroom-<version>/merged.apk --force
```

L'APK patché est écrit dans `out/` (par ex. `out/merged-patched.apk`).

**Clé de signature.** Au premier patch, ReVanced CLI crée un `.keystore` à côté de l'APK de
sortie. Mettez-le de côté et réutilisez-le à chaque mise à jour
(`VAF_KEYSTORE=/chemin/vers/le.keystore scripts/patch-with-cli.sh ...`), sinon il faudra
désinstaller (et perdre les données) à chaque fois. Détails : [toolchain.md](toolchain.md#signing-keys).

## 7. Réinstaller sur la TV à distance

L'APK re-signé ne peut pas mettre à jour la version du store : il faut d'abord désinstaller
l'original. **Cela efface les données de l'app** (vous devrez vous reconnecter).

```bash
scripts/install-apk.sh out/merged-patched.apk --replace com.disney.disneyplus
```

Le script refuse de continuer si l'app est une app système (voir §1). Équivalent manuel :

```bash
adb uninstall com.disney.disneyplus
adb install out/merged-patched.apk
```

L'installation peut prendre une minute sur Wi-Fi. L'app réapparaît dans le lanceur de la TV.

## 8. Vérifier

```bash
adb logcat -s VodAdsFree:* AndroidRuntime:E     # Ctrl+C pour arrêter
```

Lancez un contenu sur un compte avec publicités et suivez la *checklist* de l'analyse du
service (`services/<service>/analysis/`). Notez le résultat (modèle de TV, version, OK/KO) dans
la section *Findings* correspondante.

## 9. Empêcher le store d'écraser la version patchée

- **Google Play** (Android TV) : ouvrez la fiche de l'app dans le Play Store, menu **⋮** >
  décochez **Activer la mise à jour automatique** (si l'option est proposée sur votre modèle).
  Sinon, désactivez la mise à jour auto globale : Play Store > Paramètres > *Mise à jour
  automatique des applis* > *Ne pas mettre à jour automatiquement*. Comme les signatures
  diffèrent, le store ne peut de toute façon pas installer *par-dessus* ; il peut seulement
  proposer une mise à jour qui échoue.
- **Amazon Appstore** (Fire TV) : refusez la mise à jour proposée, ou désactivez les mises à jour
  automatiques dans *Paramètres > Applications > Appstore*.

## 10. Mettre à jour plus tard

À chaque nouvelle version de l'app : réinstallez la version officielle, puis refaites les étapes
4 à 7 **avec la même clé**. Pour Netflix et HBO Max, il faut aussi un fichier *targets* pour la
nouvelle version (les noms de classes changent à chaque version).

## Dépannage

| Symptôme | Cause probable / solution |
|---|---|
| `adb connect` : `Connection refused` | débogage réseau désactivé, mauvaise IP, ou port différent (Google TV : utilisez l'appairage §3) |
| `unauthorized` dans `adb devices` | acceptez la boîte de dialogue sur la TV, puis `adb disconnect && adb connect ...` |
| `more than one device/emulator` | `export ANDROID_SERIAL=<ip>:<port>` |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | la version du store est encore installée : `--replace <paquet>` |
| Le script signale une app système | préinstallée par le fabricant : non remplaçable sans root |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | APK pris sur un autre appareil : récupérez-le depuis la TV (§4) |
| `INSTALL_FAILED_MISSING_SPLIT` | vous avez installé `base.apk` seul : fusionnez les splits (§5) |
| L'app se ferme au lancement | `adb logcat -b crash` ; un patch a peut-être visé la mauvaise méthode (revoir les *targets*) |
| La connexion ADB saute | la TV s'est mise en veille : réveillez-la et relancez `adb connect` |
