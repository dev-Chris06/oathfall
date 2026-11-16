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
| 6. Niveaux 2 et 4, et les quatre autres morts | Fait |
| 7. Niveau 3 : le Sonneur | Fait |
| 8. Niveau 5 : la Fossoyeuse | Fait |
| 9. Le refuge, le menu, le texte d'ouverture | Fait |
| 10. Finition : sons, musique, équilibrage, icône, APK signé | **En cours** : sons, musiques et icône faits ; restent APK signé, équilibrage |

Le jeu s'ouvre sur **l'écran-titre** (`TitleScreen` : Continuer s'il y a une
partie, Nouvelle partie avec confirmation, Options avec crédits et effacement
de la sauvegarde). Une partie neuve passe par le texte d'ouverture
(`OpeningScreen`), puis **la carte d'Orvana** (`scripts/map/`) : la capitale
vue de face, en quatre étages, que la route en lacets gravit du fleuve au
palais. On y choisit un niveau (toucher un point, puis « Entrer ») ou le
**moulin** (le refuge, en bas à gauche) ; le bouton Menu ramène au titre.
Les cinq niveaux du chapitre 1 sont construits : la Grille, les Allées, la
Chapelle des cendres, l'Ossuaire, la Fosse. Chacun compte trois parties
séparées par des grilles qui s'ouvrent quand les morts reposent (la Fosse :
un chemin, puis la fosse ronde du boss). La fin d'un niveau l'enregistre (`Progress.mark_completed`) et
ramène à la carte ; le carnet, ouvert en plein niveau, propose « Quitter le
niveau ». Tout niveau construit reste jouable à tout moment (essais) ;
« ici » désigne le premier non terminé. Le héros qui tombe se relève au
dernier point de reprise. L'arène d'essai reste disponible (`-- --arena`).

**Le refuge** (`refuge.gd`) est le moulin, hors des murs : un niveau calme, sans
mort. Maud (boutique d'**équipement** payé en or, `Gear` et `ShopScreen`), frère
Anselme (les rites s'apprennent dans le carnet, partout ; Anselme fait
**désapprendre** tous les rites et rend les points, et il est **le seul à
enseigner les rites supérieurs**, `Progression.ADVANCED` : Garde ferme (après la
Chapelle), Veillée (après l'Ossuaire), Élan (après la Fosse), à un seul rang,
payés en points ; leurs bonus s'ajoutent à ceux des rites ordinaires) et Tibert (il pose des
questions et ouvre **le bestiaire** : un portrait et une fiche par type de
mort rencontré, `BestiaryScreen`, les inconnus restent des silhouettes). On touche PARLER près d'un personnage ; la route au sud, PARTIR,
ramène à la carte. Leurs conversations (`RefugeTexts`) s'ouvrent à mesure que
des niveaux sont terminés et ne s'entendent qu'une fois, puis un repli. Le
héros ne parle pas. **Ces textes sont publics : rien qui touche au
retournement du scénario.** Le mécanisme de textes secrets (fichier hors du
dépôt injecté au build par un secret GitHub) n'existe pas encore ; le
joueur a choisi de laisser la réplique de fin de la Fossoyeuse de côté.

**L'équipement** (`scripts/data/gear.gd`) : deux emplacements, bouclier et arme,
chacun avec des objets qui sont de **vraies pièces du modèle du chevalier**
(quatre écus, une épée, une lame longue) ou un modèle posé à sa main (la
hache, du pack squelettes). `Gear.apply()` montre exactement ce qui est porté
sur le héros, dans l'aperçu du carnet (onglet Équipement), dans la boutique
(on essaie l'objet avant de l'acheter) et en jeu. Les icônes sont des rendus
des mêmes modèles (`PortraitTool --icons`, dans `assets/ui/icons/`) : **une
icône ne doit jamais montrer autre chose que l'objet porté**. Effets : garde
(dégâts évités à genoux : Repos, corde), pointes (dégâts rendus au corps à
corps), vitesse des coups, vie, dégâts, esquive. Les anciens achats de la
boutique (gambison, cotte, lame, bottes, bandages) sont remboursés au
chargement d'une ancienne sauvegarde. Les packs ne contiennent ni cuirasse ni
bottes séparées : ne pas en vendre sans modèle fidèle.

**Fioles et vivres** (`scripts/data/supplies.gd`, boutique de Maud, onglets
Fioles et Vivres) : une fiole (au plus 3, visibles à la ceinture du héros) se
boit avec le bouton FIOLE (touche F) : 0,85 s **sans défense**, un coup ou une
esquive l'annule et la garde ; elle rend 45 de vie. Un repas emballé (pain,
fromage, jambon, ragoût ; un seul à la fois) donne son bonus pour le **prochain
niveau seulement** : `Main` le mange en partant pour un niveau (pas pour le
moulin) et il disparaît au retour à la carte. Le héros émet `flask_drunk` ;
`Level` retire la fiole et soigne.

Style de toute l'interface : « théâtre d'ombres » (silhouettes de papier noir,
nuit bleue, braises et or pâle). Les couleurs et les boutons sont dans
`Theatre`. Le chapitre 1 est écrit en chiffres romains dans les titres : le
« 1 » de la police gothique se lit comme un « i ».

Les cinq morts du chapitre existent, et les deux boss. La Chapelle et
l'Ossuaire sont souterrains (`underground`) : ni lune ni ombre portée.

Le Sonneur « ne se bat presque pas : il sonne » (scénario) : il reste sous sa
cloche, ne repousse que celui qui se colle à lui, et sonne à rythme régulier ;
chaque coup relève tous les corps sans repos. Réponses : le Repos entre deux
coups, ou **couper** les trois cordes (maintenir le bouton, qui affiche alors
COUPER, près d'une corde : 1,5 s sans défense). La troisième
corde fait tomber la cloche sur lui (35 % de sa vie, étourdi) et la cloche ne
sonne plus. Tant qu'elle sonne, de nouveaux morts se couchent dans le chœur.
Un boss tombé doit lui aussi recevoir le Repos.

La **Fossoyeuse** (la Fosse, `fossoyeuse.gd`) a trois phases, selon sa vie :
1. la pelle (coups lents et lourds, balayages), chaque coup annoncé par un
   secteur rouge au sol ; 2. elle s'enfonce, file sous terre vers un monticule
   (la zone est marquée), jaillit, déterre des Dépouilles, puis charge en
   ligne droite ; 3. elle arrache des pierres tombales et les lance (leur
   chute est marquée au sol), et un cri relève tous les corps sans repos.
Intouchable sous terre et pendant le cri qui change de phase. **La réplique
de fin que le scénario lui prête n'est volontairement écrite nulle part dans
le dépôt** (indice d'un retournement) : le niveau se termine par un message
neutre.

Le Sonneur a aussi une **frappe sismique** : s'il est à portée, il lève son maillet
(un disque rouge au sol avertit pendant 1,3 s), frappe, et une onde
s'élargit à vitesse constante jusqu'à 9,5 de lui. Elle blesse (24) celui
qu'elle traverse, sauf s'il esquive à ce moment. Le test automatique le
vérifie : touché immobile, intact en esquivant, aucune frappe hors de portée.

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
| `scripts/levels/la_chapelle.gd` | Niveau 3 : porche, nef, chœur, combat du Sonneur |
| `scripts/levels/l_ossuaire.gd` | Niveau 4 : couloirs et salles, Fouisseur, Veuve |
| `scripts/levels/la_fosse.gd` | Niveau 5 : le chemin, la fosse ronde, la Fossoyeuse |
| `scripts/levels/la_porte_des_halles.gd` | Niveau 6 (chapitre II, « Le Marché aux absents ») : place de marché, étals (`Level.stall()`), trois parties. Les niveaux 7 à 10 du chapitre sont déclarés dans `WorldData.CHAPTER_2` mais pas encore construits : Étals (Boucher, Crieur), Balance (boss : le Peseur), Caves, Halle du Prévôt (boss) |
| `scripts/levels/refuge.gd`, `npc.gd` | Le moulin et ses personnages |
| `scripts/data/refuge_texts.gd`, `gear.gd` | Conversations du refuge ; équipement (objets, effets, `Gear.apply`) |
| `scripts/dev/portrait_tool.gd` | Fabrique les portraits du bestiaire (`-- --portraits`), rendus des vrais modèles |
| `scripts/enemies/` | Comportements propres : archer (et son carreau), Porte-cloche, Fouisseur, Veuve, Sonneur, la grosse cloche avec ses cordes (`great_bell.gd`, `bell_rope.gd`), Fossoyeuse et ses pierres (`fossoyeuse.gd`, `grave_stone.gd`) |
| `scripts/audio.gd` | Chargé en permanence (`Audio`) : bruitages (`Audio.play(&"clang")`), musiques en fondu (`Audio.music(&"boss")`), volumes des options. Événements et fichiers déclarés dans ses tableaux `EVENTS` et `TRACKS` |
| `tools/audio/generate.py` | Fabrique les bruitages lourds et les six musiques en boucle (`python3 -I tools/audio/generate.py assets/audio`), reproductible |
| `scripts/fx.gd` | Effets partagés : ondes au sol, matériaux simples |
| `scripts/map/` | La carte : `world_map.gd` (écran, défilement, choix), `map_scene.gd` (la ville dessinée par code) |
| `scripts/data/world_data.gd` | Chapitres et niveaux dans l'ordre de la route |
| `scripts/ui/` | Polices, thème « théâtre d'ombres » (`Theatre`), page découpée du carnet, ciel de nuit, boîte de dialogue, boutique, écran-titre, ouverture |
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
- **Icônes d'objets** : `assets/ui/icons/<objet>.png`, générées par
  `godot --path . --resolution 800x600 -- --icons` ; un nouvel objet de `Gear`
  relance l'outil, et le test vérifie qu'elles existent.
- **Portraits** : `assets/ui/portraits/<type>.png`, versionnés, rendus par
  `PortraitTool` à partir des vrais modèles. Un nouveau type de mort ajoute
  sa fiche `bestiary` dans `enemy_types.gd` et relance l'outil ; le test
  vérifie qu'ils existent tous.
- **Interaction hors combat** : le niveau donne `hero.interaction_label`
  (« PARLER », « PARTIR »), le bouton du rite l'affiche, et le héros émet
  `interacted` à l'appui. Les corps et les cordes ont la priorité.
- **Un type de mort** se déclare dans `enemy_types.gd` avec son `behavior`
  (`melee`, `archer`, `bell`, `burrower`, `widow`, `sonneur`, `fossoyeuse`) ; `Enemy.create()`
  choisit la classe. Un comportement écrit `_chase()` et, pour ses actions
  propres, `_special()` dans l'état SPECIAL. Frapper un mort en SPECIAL
  l'interrompt.
- **Un coup se cale sur son animation** : le coup visible doit tomber au
  moment où les dégâts sont appliqués (`attack_windup`), sinon on voit le
  coup toucher puis les dégâts n'arrivent que plus tard, et il suffit de
  s'écarter entre les deux. Le type donne `attack_impact` (part de
  l'animation où le coup frappe, mesurée sur le modèle) et `Enemy._play_attack`
  / `_play_blow` règlent la vitesse. Un nouveau geste dangereux ajoute son
  `*_impact` et une ligne au test d'alignement. Pas de « fenêtre d'impact »
  après coup : elle rendrait l'esquive plus stricte.
- **Boss** : le type porte `"boss": true` ; le niveau affiche sa barre avec
  `hud.show_boss()` / `hud.set_boss()` / `hud.hide_boss()`, alimentée par le
  signal `Enemy.health_changed`. Un boss qui ne chasse personne garde un
  minuteur qui court quel que soit son état (sinon un héros qui le harcèle
  l'empêche d'agir).
- **Grilles** : `add_gate(position, point_de_reprise)` ; au retour à un point
  de reprise, les grilles d'avant sont ouvertes.
- **Corps et obstacles** : la chute projette le corps ; il peut finir derrière
  une grille. Le rite se mesure donc avec `Enemy.distance_to_body()`, qui
  accepte aussi le point de chute.
- **Caméra et décor** : la caméra est à 6,6 de haut et 7,4 en arrière. Le
  héros ne doit jamais pouvoir passer derrière un décor plus haut qu'elle
  (les mausolées) : fermer ces recoins.
- **Nouveau niveau** : l'ajouter à `Main.LEVELS` ; il est déjà nommé dans
  `WorldData` (chapitre 1). Un autre chapitre demande d'abord d'écrire ses
  niveaux dans `WorldData`.
- **Textes à l'écran** : polices de `GameFonts` (CC0). La gothique n'a pas
  d'accents : la réserver aux titres, avec la police de texte en secours.
- **Sol** : `pave()` dessine tous les carreaux en un seul appel. Ne pas
  poser les carreaux un par un.
- **Entrées** : le jeu ne lit que `TouchControls.move`, `rite_held` et les
  signaux `attack_pressed`, `dodge_pressed`, `flask_pressed` et `book_pressed`.
- **Caractéristiques du héros** : la progression les calcule
  (`Progress.hero_stats()`) et le niveau les applique avec
  `hero.apply_stats()`. Le héros ne lit jamais `Progress` lui-même.
- **Hasard des tests** : `Main` fixe la graine du hasard en mode test
  (`seed(...)`) : la Fosse tire au sort ses monticules et ses Dépouilles, et un
  test qui réussit une fois doit réussir toujours.
- **Tests et sauvegarde** : en mode test ou capture, `Main` écrit dans
  `user://essai.json`, jamais dans la vraie sauvegarde du joueur.

**Le son** : un nouveau bruit s'ajoute à `Audio.EVENTS` (fichier dans
`assets/audio/sfx/`, ou `kenney/`) et s'appelle par `Audio.play(&"nom")` ; le
test vérifie que les fichiers existent et que les événements attendus ont été
joués. Musique par niveau : `music_track` (cimetière par défaut, souterrain si
`underground`, `refuge`), `boss` dès que `hud.show_boss()` est appelé. Volumes
dans Options, gardés dans `user://reglages.json`.

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
- **Interface sans parent Control** : un `Control` posé sous un `Node` ou un
  `CanvasLayer` garde une taille nulle avec `set_anchors_preset` seul (tout
  s'empile en haut à gauche, rien ne se dessine). Utiliser
  `set_anchors_and_offsets_preset`.
- **Modifications scriptées** : une modification faite par script qui ne
  trouve pas son texte ne signale rien. Toujours vérifier qu'elle a porté
  (`assert` avant de remplacer, ou relire le fichier).

## Économie de moyens

- Éviter les grandes recherches web et les agents délégués : les décisions de
  fond sont prises.
- Regarder peu d'images, et seulement celles qui tranchent une question.
- Préférer des étapes courtes, chacune terminée par le test automatique, un
  commit et un build.
