# Télécommande Samsung — app iOS SwiftUI

Une télécommande pour téléviseur Samsung Tizen (modèles 2016 et suivants), écrite
en SwiftUI natif, sans dépendance externe.

## Ce que fait l'app

- **Découverte automatique** de la TV sur le Wi-Fi (balayage du sous-réseau /24 sur le port 8001)
- **Ajout manuel** par adresse IP si la découverte échoue
- **Appairage par jeton** : la TV demande l'autorisation une seule fois, le jeton est conservé
- **Commandes** : marche/arrêt, source, volume, muet, chaînes, croix directionnelle + OK,
  retour / accueil / menu / guide, lecture-pause-avance-retour, pavé numérique
- **Saisie de texte** dans les champs de la TV (recherche, mot de passe Wi-Fi…)
- **Raccourcis d'applications** (Netflix, YouTube, Prime Video, Disney+, Spotify, Molotov)
- **Wake-on-LAN** pour rallumer la TV quand le canal de commande est coupé

## Démarrage

1. Ouvrir `SamsungRemote.xcodeproj` avec **Xcode 16 ou plus récent**
   (le projet utilise les groupes synchronisés au système de fichiers).
2. Cibler `SamsungRemote` › ton iPhone.
3. Onglet **Signing & Capabilities** : choisir ton équipe (compte Apple gratuit suffisant)
   et, si besoin, changer l'identifiant de bundle `fr.gabbtry.SamsungRemote`.
4. Lancer. Cible minimale : **iOS 17**.

Au premier lancement, iOS demande l'autorisation d'accès au **réseau local** :
sans elle, ni la découverte ni les commandes ne fonctionnent.
(Réglages › Télécommande › Réseau local, en cas de refus initial.)

## Appairage

1. Allumer la TV et la connecter au **même Wi-Fi** que l'iPhone.
2. Lancer la recherche depuis l'app, sélectionner la TV.
3. La TV affiche une demande d'autorisation pour l'appareil « iPhone » → **Autoriser**.
4. Le bandeau passe au vert : les commandes sont actives.

Si l'autorisation a été refusée par erreur, la TV mémorise le refus. Il faut alors
la retirer sur la TV : *Paramètres › Général › Gestionnaire de périphériques externes ›
Gestionnaire de connexion des périphériques › Liste des périphériques*. Côté app,
« Oublier l'appairage » force une nouvelle demande.

## Fonctionnement technique

Les TV Samsung Tizen exposent un canal WebSocket de télécommande :

```
wss://<ip>:8002/api/v2/channels/samsung.remote.control?name=<nom en base64>[&token=<jeton>]
```

Les commandes sont des messages JSON :

```json
{"method":"ms.remote.control",
 "params":{"Cmd":"Click","DataOfCmd":"KEY_VOLUP","Option":"false","TypeOfRemote":"SendRemoteKey"}}
```

Deux particularités traitées dans le code :

- le port 8002 présente un **certificat auto-signé** → `SamsungTVClient` accepte
  explicitement la confiance serveur via `URLSessionDelegate` ;
- l'API d'information (`http://<ip>:8001/api/v2/`) est en **HTTP clair** →
  `NSAllowsLocalNetworking` dans `Info.plist`, ce qui n'ouvre que le réseau local.

La découverte se fait en **unicast** sur les 254 adresses du sous-réseau plutôt qu'en
SSDP : le multicast exigerait l'entitlement `com.apple.developer.networking.multicast`,
soumis à validation par Apple.

## Limites connues

- **Wake-on-LAN** : l'envoi vers l'adresse de diffusion demande le même entitlement
  multicast. L'app envoie donc aussi le paquet en unicast vers la dernière IP connue,
  ce qui fonctionne tant que l'entrée ARP du routeur est fraîche (TV éteinte depuis
  peu). Il faut par ailleurs activer *Mise sous tension par mobile* / *Réseau en veille*
  dans les réglages de la TV.
- Le **jeton d'appairage** est stocké dans `UserDefaults`. Il ne donne accès qu'à la
  télécommande d'une TV sur le réseau local ; passer au trousseau serait plus propre.
- La découverte suppose un sous-réseau **/24**, le cas courant en résidentiel.
- Les **identifiants d'apps** Tizen varient selon les régions et les millésimes. Un
  raccourci qui ne lance rien signifie que l'app n'est pas installée ou porte un autre
  identifiant sur ce modèle — la liste est dans `Models/TVApp.swift`.

## Structure

```
SamsungRemote/
├── Info.plist
├── SamsungRemote.xcodeproj/
└── SamsungRemote/
    ├── SamsungRemoteApp.swift      point d'entrée
    ├── Models/
    │   ├── TVDevice.swift          TV connue + jeton
    │   ├── TVStore.swift           persistance (UserDefaults)
    │   ├── RemoteKey.swift         codes touches KEY_*
    │   └── TVApp.swift             raccourcis d'applications
    ├── Networking/
    │   ├── SamsungTVClient.swift   canal WebSocket + appairage
    │   ├── TVDiscovery.swift       balayage du sous-réseau
    │   ├── WakeOnLAN.swift         paquet magique
    │   └── LocalNetwork.swift      adresse Wi-Fi de l'iPhone
    └── Views/
        ├── ContentView.swift       aiguillage config / télécommande
        ├── SetupView.swift         découverte et choix de la TV
        ├── RemoteView.swift        télécommande
        └── RemoteControls.swift    boutons, bascules, croix directionnelle
```
