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
| 4. Niveau 1, La Grille : décor, vagues scénarisées, fin de niveau | **À faire, c'est la suite** |
| 5. Progression : souvenirs, niveaux du héros, or, compétences, sauvegarde | À faire |
| 6. Niveaux 2 et 4, et les quatre autres morts | À faire |
| 7. Niveau 3 : le Sonneur | À faire |
| 8. Niveau 5 : la Fossoyeuse | À faire |
| 9. Le refuge, le menu, le texte d'ouverture | À faire |
| 10. Finition : sons, musique, équilibrage, icône, APK signé | À faire |

L'état actuel du jeu est une arène : des Dépouilles arrivent par vagues, et
une vague n'est finie que lorsque tous les morts reposent. `scripts/main.gd`
construit encore la salle par code ; l'étape 4 doit le remplacer par un vrai
système de niveaux.

Retour de l'auteur encore attendu : les sensations de combat sur téléphone
(poids des coups, vitesse, difficulté, confort des boutons).

## Organisation du code

| Fichier | Rôle |
|---|---|
| `scripts/main.gd` | L'arène : décor, vagues, liaison entre les éléments |
| `scripts/hero.gd` | Le héros : états MOVE, ATTACK, DODGE, HIT, RITE, DEAD |
| `scripts/enemy.gd` | Un mort : CHASE, WINDUP, STAGGER, DOWN, RISING, RESTED |
| `scripts/touch_controls.gd` | Joystick, boutons tactiles, clavier |
| `scripts/game_camera.gd` | Caméra qui suit le héros et tremble à l'impact |
| `scripts/hud.gd` | Barre de vie, compteurs, messages |
| `scripts/data/hero_classes.gd` | Valeurs et animations des classes |
| `scripts/data/enemy_types.gd` | Valeurs et animations des types de morts |
| `scripts/dev/selftest_bot.gd` | Joueur automatique pour les tests |

Règles à garder :

- **Les noms d'animations et les valeurs de combat vivent dans `scripts/data/`**,
  jamais dans le code du héros ou des ennemis. Changer de pack de modèles doit
  se réduire à modifier ces tableaux.
- **Groupes** : `hittable` pour ce qui peut être frappé, `bodies` pour les
  corps au sol.
- **Les modèles regardent vers +Z.** L'orientation se calcule avec
  `atan2(direction.x, direction.z)`.
- **Entrées** : le jeu ne lit que `TouchControls.move`, `rite_held` et les
  signaux `attack_pressed` et `dodge_pressed`.

## Vérifier son travail

Godot 4.7.2 est installé et accessible par la commande `godot`.

```
# Réimporter après un ajout de fichiers
godot --headless --path . --import

# Test automatique : un joueur automatique livre un vrai combat
godot --headless --path . --fixed-fps 60 -- --selftest

# Voir le rendu : ouvre une fenêtre, enregistre des images, puis quitte
godot --path . --resolution 1280x720 -- --capture=/chemin/vers/un/dossier
```

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
