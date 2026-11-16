# Oathfall — consignes de travail

Ce fichier donne à un agent qui reprend le projet tout ce qu'il lui faut pour
continuer sans relire l'historique. Le dépôt est public : ne rien écrire ici,
ni ailleurs dans le dépôt, qui révèle les retournements du scénario.

## Le projet

Action-RPG dark fantasy en 3D pour Android, réalisé avec Godot 4.7 (rendu
Compatibilité, écran en paysage). Le royaume d'Orvana a prêté un serment :
nul n'y meurt plus. Le joueur incarne un soldat de la dernière légion.

Mécanique centrale, **le Repos** : un mort abattu reste au sol puis se relève
après un délai, sauf si le héros se tient près du corps et maintient le bouton
REPOS une seconde, sans défense. Tout le jeu (monstres, boss, niveaux) est
conçu autour de ce choix : frapper ceux qui sont debout, ou mettre au repos
ceux qui sont tombés.

Le scénario détaillé est dans `histoires.txt`, à la racine du projet. Ce
fichier est ignoré par git et doit le rester. C'est la « piste 1 » de ce
document qui est réalisée ; les pistes 2 et 3 sont d'autres jeux, pour plus
tard.

## Décisions prises par l'auteur

- **Titre** : Oathfall. **Royaume** : Orvana.
- **Langue** : tout est en français (textes du jeu, commentaires, commits,
  échanges avec l'auteur).
- **Ton** : sombre et sérieux. Ne jamais proposer de visuels mignons.
- **Budget** : zéro. Ne rien acheter.
- **Assets** : uniquement CC0 ou CC-BY, parce que le dépôt est public. Chaque
  ajout est noté dans `CREDITS.md`, avec sa licence relue dans l'archive.
- **Modèles actuels** : packs KayKit (style « figurine »). L'auteur les trouve
  un peu enfantins mais les accepte pour la v1. Le passage à des personnages
  aux proportions adultes est remis à plus tard ; il demandait Blender, qui
  n'est pas installé.
- **Classes** : quatre sont déclarées dans `scripts/data/hero_classes.gd`.
  Seul le Porte-glaive est jouable. Les trois autres viendront une fois le
  chapitre 1 terminé.
- **Autonomie** : l'auteur a donné carte blanche jusqu'à la fin du jeu.
  Décider, faire, puis rendre compte, plutôt que demander à chaque étape.
- **Droits** : pas de licence libre sur le code ni sur l'histoire.

## La v1 : le chapitre 1, « Les Faubourgs muets »

Cinq niveaux, cinq types de morts, deux boss, un refuge.

| Niveau | Lieu | Contenu |
|---|---|---|
| 1 | La Grille | Cour du cimetière. Dépouilles. Le joueur découvre le Repos |
| 2 | Les Allées | Mausolées. Arrivée de l'Archer creux et du Porte-cloche |
| 3 | La Chapelle des cendres | Boss intermédiaire : le Sonneur |
| 4 | L'Ossuaire | Couloirs étroits. Arrivée du Fouisseur et de la Veuve |
| 5 | La Fosse | Boss : la Fossoyeuse, en trois phases |

Les morts du chapitre :

- **Dépouille** : lente, au corps à corps, en groupe. Déjà faite.
- **Archer creux** : fragile, tire de loin, recule quand on approche.
- **Porte-cloche** : rare ; tant qu'il sonne, les corps se relèvent plus vite.
- **Fouisseur** : jaillit du sol ou des murs.
- **Veuve** : ne frappe pas, mais relève tous les corps d'un cri.

Les boss :

- **Le Sonneur** : chaque coup de cloche relève d'un coup tous les corps sans
  repos. Il faut donner le Repos entre deux coups, ou couper les cordes.
- **La Fossoyeuse** : coups de pelle lents et lourds ; elle s'enfonce dans la
  terre et ressort ailleurs en déterrant des Dépouilles ; en dernière phase,
  elle lance des pierres tombales et relève tous les corps laissés sans repos.

Le refuge est un moulin hors des murs, avec une boutique, un lieu pour
apprendre les compétences et quelques personnages à qui parler.

## Avancement

| Étape | État |
|---|---|
| 0. Projet, build automatique, salle de test | Fait |
| 1. Le héros : déplacement, enchaînement, esquive, commandes tactiles | Fait |
| 2. La Dépouille | Fait |
| 3. Le Repos | Fait |
| 4. Niveau 1, La Grille : décor, vagues scénarisées, fin de niveau | Fait |
| 5. Progression : souvenirs, niveaux du héros, or, compétences, sauvegarde | Fait |
| 6. Niveaux 2 et 4, et les quatre autres morts | **À faire, c'est la suite** |
| 7. Niveau 3 : le Sonneur | À faire |
| 8. Niveau 5 : la Fossoyeuse | À faire |
| 9. Le refuge, le menu, le texte d'ouverture | À faire |
| 10. Finition : sons, musique, équilibrage, icône, APK signé | À faire |

Le jeu s'ouvre sur la Grille : trois cours séparées par des grilles, chacune
ouverte quand ses morts reposent, puis la sortie derrière le caveau. Le
héros qui tombe se relève au dernier point de reprise, avec les souvenirs
qu'il y portait. La fin du niveau affiche un bilan puis relance la Grille,
en attendant les Allées. L'arène d'essai reste disponible (`-- --arena`).

Progression : chaque Repos donné rend des souvenirs (l'expérience) et de
l'or. Les paliers de niveau donnent de la vie et des points de compétence,
dépensés dans le CARNET (bouton en haut à droite, jeu en pause). Au refuge
(étape 9), Frère Anselme enseignera les compétences et Maud vendra contre
l'or ; le carnet restera pour consulter. La partie est sauvegardée dans
`user://sauvegarde.json` aux points de reprise, en fin de niveau et à chaque
compétence apprise ; le jeu reprend là où on l'a laissé. Mourir ne fait rien
perdre : on reprend la cour au début.

Retour de l'auteur encore attendu : les sensations de combat sur téléphone
(poids des coups, vitesse, difficulté, confort des boutons).

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/main.gd` | Point d'entrée : charge les niveaux, points de reprise |
| `scripts/level.gd` | Base des niveaux : héros, caméra, HUD, apparition des morts, outils de scénario (`say`, `reach`, `until_peace`, `wait`) |
| `scripts/levels/la_grille.gd` | Niveau 1 : décor, grilles, scénario |
| `scripts/levels/les_allees.gd` | Niveau 2 : allée de mausolées, archers, Porte-cloche |
| `scripts/enemies/` | Comportements propres : archer (et son carreau), Porte-cloche, Fouisseur, Veuve |
| `scripts/fx.gd` | Effets partagés : ondes au sol, matériaux simples |
| `scripts/ui/` | Polices du jeu, parchemin du carnet |
| `scripts/levels/arena.gd` | Salle d'essai, utilisée par le test automatique |
| `scripts/progress.gd` | Chargé en permanence (`Progress`) : souvenirs, niveau, or, compétences, sauvegarde |
| `scripts/skill_book.gd` | Le carnet : écran des compétences |
| `scripts/hero.gd` | Le héros : états MOVE, ATTACK, DODGE, HIT, RITE, DEAD |
| `scripts/enemy.gd` | Un mort : CHASE, WINDUP, STAGGER, DOWN, RISING, RESTED |
| `scripts/touch_controls.gd` | Joystick, boutons tactiles, clavier |
| `scripts/game_camera.gd` | Caméra qui suit le héros et tremble à l'impact |
| `scripts/hud.gd` | Barre de vie, compteurs, messages |
| `scripts/data/hero_classes.gd` | Valeurs et animations des classes |
| `scripts/data/enemy_types.gd` | Valeurs et animations des types de morts |
| `scripts/data/progression.gd` | Paliers de niveau, caractéristiques de base, compétences |
| `scripts/dev/selftest_bot.gd` | Joueur automatique pour les tests |

Règles à garder :

- **Les noms d'animations et les valeurs de combat vivent dans `scripts/data/`**,
  jamais dans le code du héros ou des ennemis. Changer de pack de modèles doit
  se réduire à modifier ces tableaux.
- **Groupes** : `hittable` pour ce qui peut être frappé, `bodies` pour les
  corps au sol.
- **Les modèles regardent vers +Z.** L'orientation se calcule avec
  `atan2(direction.x, direction.z)`.
- **Un niveau** hérite de `Level` et écrit `_build()` (décor),
  `_run(point_de_reprise)` (scénario) et `_checkpoint_position()`. Il signale
  `completed`, `failed` et `checkpoint_reached` ; `Main` fait le reste. Le
  niveau avance vers -Z, dos à la caméra. Il fixe `objective` quand le héros
  doit rejoindre un point : le joueur automatique s'en sert.
- **Scénarios** : attendre avec `wait()` ou `wait_until()` du niveau, jamais
  avec un minuteur de l'arbre, pour que tout s'arrête si le niveau est
  rechargé.
- **Un type de mort** se déclare dans `enemy_types.gd` avec son `behavior`
  (`melee`, `archer`, `bell`, `burrower`, `widow`) ; `Enemy.create()`
  choisit la classe. Un comportement écrit `_chase()` et, pour ses actions
  propres, `_special()` dans l'état SPECIAL. Frapper un mort en SPECIAL
  l'interrompt.
- **Grilles** : `add_gate(position, point_de_reprise)` ; au retour à un point
  de reprise, les grilles d'avant sont ouvertes.
- **Textes à l'écran** : polices de `GameFonts` (CC0). La gothique n'a pas
  d'accents : la réserver aux titres, avec la police de texte en secours.
- **Sol** : `pave()` dessine tous les carreaux en un seul appel. Ne pas
  poser les carreaux un par un.
- **Entrées** : le jeu ne lit que `TouchControls.move`, `rite_held` et les
  signaux `attack_pressed`, `dodge_pressed` et `book_pressed`.
- **Caractéristiques du héros** : la progression les calcule
  (`Progress.hero_stats()`) et le niveau les applique avec
  `hero.apply_stats()`. Le héros ne lit jamais `Progress` lui-même.
- **Tests et sauvegarde** : en mode test ou capture, `Main` écrit dans
  `user://essai.json`, jamais dans la vraie sauvegarde du joueur.

## Vérifier son travail

Godot 4.7.2 est installé et accessible par la commande `godot`.

```
# Réimporter après un ajout de fichiers
godot --headless --path . --import

# Test automatique : combats d'essai dans l'arène, puis traversée de la
# Grille, avec une chute volontaire pour vérifier la reprise
godot --headless --path . --fixed-fps 60 -- --selftest

# Voir le rendu : ouvre une fenêtre, enregistre des images, puis quitte
# (ajouter --level=les_allees pour un autre niveau)
godot --path . --resolution 1280x720 -- --capture=/chemin/vers/un/dossier
# … en commençant à un point de reprise
godot --path . --resolution 1280x720 -- --capture=/chemin --checkpoint=2
```

- Le joueur automatique joue comme un joueur moyen : il choisit ses cibles
  (archers, cloches, Veuves d'abord) et esquive les tirs annoncés. S'il tombe
  souvent dans un niveau (il affiche « chute du héros »), le niveau est
  probablement trop dur : alléger les vagues plutôt que l'aider davantage.
- Le test doit se terminer par `SELFTEST OK`. Il est aussi exécuté par le
  build, qui échoue sinon. **Toute nouvelle mécanique doit y gagner une
  vérification.**
- Le mode capture est le seul moyen de voir l'image : sans affichage, Godot
  ne dessine rien. Regarder les images produites avant de dire qu'un rendu
  est bon.
- Les images par seconde mesurées en mode capture ne sont pas fiables : la
  fenêtre passe souvent en arrière-plan et le bureau la ralentit. Pour
  mesurer, ajouter `--disable-vsync` et garder la fenêtre au premier plan.

## Build et publication

Chaque envoi sur `main` lance `.github/workflows/build-android.yml` : test
automatique, export de l'APK, puis publication sur la page fixe
`releases/tag/dev`. L'auteur installe l'APK depuis cette page sur son
téléphone.

À chaque version, augmenter ensemble :

- `config/version` dans `project.godot` ;
- `version/code` et `version/name` dans `export_presets.cfg`.

La clé de signature de test est dans les secrets du dépôt
(`DEBUG_KEYSTORE_B64`, `DEBUG_KEYSTORE_PASSWORD`). Aucune clé ne doit entrer
dans le dépôt.

## Pièges déjà rencontrés

- **Ombres** : par défaut, l'ombre d'une lumière directionnelle se calcule en
  quatre passes et redessine toute la scène quatre fois. Garder
  `SHADOW_ORTHOGONAL`, une portée courte, et les réglages allégés de
  `project.godot`. Pas d'ombres sur les torches.
- **Chute des squelettes** : l'animation `Death_C_Skeletons` projette le corps
  à près de deux unités de l'origine du personnage. Utiliser
  `Enemy.body_position()` pour tout ce qui concerne un corps au sol.
- **Chevalier KayKit** : le modèle porte toutes ses armes à la fois. Les
  pièces à masquer sont listées dans `hidden_parts`.
- **Arrêt sur image à l'impact** : il modifie `Engine.time_scale`. Les
  minuteries qui doivent l'ignorer se créent avec `ignore_time_scale` à vrai.
- **Machine de l'auteur** : peu de mémoire et une carte graphique intégrée
  ancienne. Tout ce qui est lourd (export Android) passe par GitHub Actions.
- **Téléphone de test** : puce Mali-G57 MC2, écran 60 Hz. La première salle y
  tournait vers 30 images par seconde avant l'allègement des ombres ; la
  mesure après correction reste à refaire.

## Économie de moyens

- Éviter les grandes recherches web et les agents délégués : les décisions de
  fond sont prises.
- Regarder peu d'images, et seulement celles qui tranchent une question.
- Préférer des étapes courtes, chacune terminée par le test automatique, un
  commit et un build.
