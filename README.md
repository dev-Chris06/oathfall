# Oathfall

Action-RPG dark fantasy en 3D pour Android, réalisé avec Godot 4.

Le royaume d'Orvana perdait une guerre de vingt ans. Son roi a prêté un
serment : « Nul ne mourra plus en Orvana. » Le serment a tenu. Vous êtes un
soldat de la dernière légion, et vous rentrez chez vous.

## État du projet

Le jeu est en tout début de développement. L'étape en cours est l'étape 0 :
une salle de test qui vérifie que la 3D tourne correctement sur téléphone.

## Télécharger le dernier build de test

Chaque envoi sur la branche `main` construit un APK de test, publié ici :

**[Dernier build de test](../../releases/tag/dev)**

Sur le téléphone, ouvrir ce lien, télécharger `oathfall-debug.apk` puis
l'installer (autoriser l'installation depuis des sources inconnues si le
système le demande).

## Ouvrir le projet

Le projet demande Godot 4.7 ou plus récent, avec le moteur de rendu
« Compatibilité ».

```
godot --path . --editor
```

## Organisation

| Dossier | Contenu |
|---|---|
| `scenes/` | Les scènes du jeu |
| `scripts/` | Le code GDScript |
| `assets/` | Les modèles 3D, avec leur licence |
| `.github/workflows/` | La construction automatique de l'APK |

## Droits

Le code, l'histoire et les textes de ce dépôt ne sont pas sous licence libre :
tous droits réservés. Le dépôt est public pour être consulté, pas pour être
réutilisé.

Les modèles 3D viennent de packs sous licence CC0, listés dans
[CREDITS.md](CREDITS.md).
