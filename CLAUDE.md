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
de la sauvegarde, **Mise à jour** : `UpdateCheck` lit la version au début des
notes de la page `releases/tag/dev`, « Version x.y.z. », écrite par le build,
et propose de télécharger l'APK ; permission Internet activée). Une partie neuve passe par le texte d'ouverture
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

**Le chapitre II** (niveaux 6 à 10) est construit : la Porte des halles, les Étals,
la Balance, les Caves du marché, la Halle du Prévôt. Les morts y sont plus
solides (+30 % de vie, +20 % de dégâts, corps qui se relèvent plus vite :
`Enemy.apply_chapter`, `Level.chapter`). Les armes coûtent le double.

**Armure d'élan** (`"armor": true` dans les données) : un mort à armure n'est
pas interrompu pendant son coup, n'est pas ébranlé deux fois de suite
(`stagger_guard`), enchaîne parfois deux coups (`combo_chance`) et reste
**ouvert** après un coup (`open_time` : il subit ×1,5). On esquive puis on
frappe, on n'enchaîne pas.

- **Boucher** (`butcher.gd`, 150 de vie, armure) : charge annoncée par une bande
  rouge quand le héros est loin ; il s'assomme s'il heurte un mur ; sous la
  moitié de sa vie il enrage (hâte et force permanentes, anneau rouge).
- **Crieur** (`crier.gd`) : il ne frappe pas. Il crie quand au moins deux morts
  se battent contre le héros : ils sont **pressés** (×1,45 de vitesse, ×1,4 de
  dégâts, anneau rouge aux pieds, `Enemy.hasten`). Seul, il **appelle du renfort**
  (deux Dépouilles, `call_requested`, du côté du héros). Le frapper pendant qu'il
  prend son souffle l'interrompt. La cloche agit sur les corps, lui sur les vivants.
- **Peseur** (boss) : sa balance compare morts debout et corps. Trop de morts
  debout : il ne subit que 35 % (anneau gris). Trop de corps : il s'emballe (hâte
  permanente, anneau rouge) et lance trois poids à la fois. À l'**équilibre** : il
  est assommé 3 s et subit ×2 (anneau doré ; au plus une fois toutes les 9 s).
  Les poids sont annoncés au sol et varient : visés avec de l'avance, par paires,
  en rouleau de cinq. Un indicateur de balance s'affiche sous la barre du boss
  (`Hud.set_balance`).
- **Prévôt** (boss) : armure et enchaînement. Il lève l'impôt : un cercle d'or
  (de plus en plus petit selon le tiers de sa vie, qui dérive) est annoncé ; la
  levée frappe tout hors du cercle et **relève les corps** hors du cercle ; au
  dernier tiers un faux cercle terne l'accompagne. À chaque tiers il décrète
  (intouchable 1,6 s) et convoque ses percepteurs.

**Difficulté** (choix de l'auteur, après les retours des testeurs) : le héros
a l'**armure d'élan** : un coup le blesse sans l'arrêter (il continue de
frapper, courir, esquiver), sauf agenouillé (Repos, corde) ou en buvant, où il
reste interrompu. On garde la foule : **pas de limite** au nombre de morts qui
frappent à la fois, ni d'invulnérabilité après un coup. Chaque point de reprise
remonte la vie à 60 % au moins (`Supplies.CHECKPOINT_HEALTH`,
`Level.mark_checkpoint`). La difficulté monte par chapitre ; des modes plus
durs (rejouer un chapitre fini, mêmes niveaux) viendront plus tard.

Le joueur automatique joue comme un joueur attentif : il esquive, recule devant
un coup à armure et frappe quand le mort est ouvert, vise les Crieurs d'abord,
rejoint le cercle d'or, boit ses fioles (il en a trois) et, au chapitre II,
s'équipe (lame longue, rondache). `-- --selftest --only=<niveau>` ne traverse
qu'un niveau (mise au point).

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
esquive l'annule et la garde ; elle rend 45 de vie. Une partie neuve commence avec
**2 fioles** (`Supplies.START_FLASKS`) ; chaque Repos a une chance sur douze
de faire tomber une fiole (`FlaskPickup`, ramassée en passant dessus, laissée
au sol si on en porte déjà 3 ; l'arène d'essai la coupe). Un repas emballé (pain,
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
| `scripts/levels/la_porte_des_halles.gd` | Niveau 6 (chapitre II, « Le Marché aux absents ») : place de marché, étals (`Level.stall()`), trois parties |
| `scripts/levels/les_etals.gd` | Niveau 7 : la rue des bouchers, étals aux carcasses, Boucher et Crieur, deux barrières |
| `scripts/levels/la_balance.gd` | Niveau 8, boss intermédiaire : la place des poids et mesures, le Peseur, la balance publique qui penche en direct |
| `scripts/levels/les_caves.gd` | Niveau 9 : les caves du marché, souterraines (couloirs et trois salles de tonneaux), tous les morts du chapitre |
| `scripts/levels/la_halle_du_prevot.gd` | Niveau 10, boss : la halle voûtée, antichambre puis le Prévôt ; fin du chapitre II |
| `scripts/levels/refuge.gd`, `npc.gd` | Le moulin et ses personnages |
| `scripts/data/refuge_texts.gd`, `gear.gd` | Conversations du refuge ; équipement (objets, effets, `Gear.apply`) |
| `scripts/dev/portrait_tool.gd` | Fabrique les portraits du bestiaire (`-- --portraits`), rendus des vrais modèles |
| `scripts/enemies/` | Comportements propres : archer (et son carreau), Porte-cloche, Fouisseur, Veuve, Sonneur, la grosse cloche avec ses cordes (`great_bell.gd`, `bell_rope.gd`), Fossoyeuse et ses pierres (`fossoyeuse.gd`, `grave_stone.gd`) |
| `scripts/enemies/butcher.gd`, `crier.gd`, `peseur.gd`, `prevot.gd` | Chapitre II : le Boucher (charge), le Crieur (hâte et renfort), le Peseur (boss : la balance), le Prévôt (boss : la levée et le cercle d'or) |
| `scripts/audio.gd` | Chargé en permanence (`Audio`) : bruitages (`Audio.play(&"clang")`), musiques en fondu (`Audio.music(&"boss")`), volumes des options. Événements et fichiers déclarés dans ses tableaux `EVENTS` et `TRACKS` |
| `tools/audio/generate.py` | Fabrique les bruitages lourds et les six musiques en boucle (`python3 -I tools/audio/generate.py assets/audio`), reproductible |
| `scripts/fx.gd` | Effets partagés : ondes au sol, matériaux simples |
| `scripts/map/` | La carte : `world_map.gd` (écran, défilement, pincement, choix, fiche du lieu, travelling, plongée), `map_scene.gd` (le **modèle** de la carte : positions de la route et des niveaux, états, étages ; il n'est plus affiché), `map_world.gd` (la scène 3D : route de braises, brasiers, moulin, fleuve, fondations, corbeau, caméra), `map_terrain.gd` (le **relief** : plateaux pavés, falaises, rampes, lit du fleuve, collines ; maillage fabriqué d'avance), `map_city.gd` (les **bâtiments** KayKit Medieval, regroupés par quartier, matériau de nuit, fenêtres), `map_life.gd` (la **ville qui se souvient** : brume, fenêtres, morts errants, corbeaux) |
| `scripts/data/world_data.gd` | Chapitres et niveaux dans l'ordre de la route |
| `scripts/ui/` | Polices, thème « théâtre d'ombres » (`Theatre`), page découpée du carnet, ciel de nuit, boîte de dialogue, boutique, écran-titre, ouverture |
| `scripts/levels/arena.gd` | Salle d'essai, utilisée par le test automatique |
| `scripts/progress.gd` | Chargé en permanence (`Progress`) : souvenirs, niveau, or, compétences, sauvegarde |
| `scripts/skill_book.gd` | Le carnet : écran des compétences |
| `scripts/hero.gd` | Le héros : états MOVE, ATTACK, DODGE, HIT, RITE, DEAD, DRINK, CAST (rite de combat) |
| `scripts/data/rites.gd`, `scripts/rites/` | Les rites de combat (`RiteData`) ; leur exécution (`HeroRites`), le cierge, la lame de l'Absoute, l'allié du Rappel |
| `scripts/ui/rite_icons.gd`, `rite_preview.gd` | Icônes des rites, dessinées en code ; courte animation de chaque rite (carnet, découverte) |
| `scripts/enemy.gd` | Un mort : CHASE, WINDUP, STAGGER, DOWN, RISING, RESTED |
| `scripts/touch_controls.gd` | Joystick, boutons tactiles, clavier |
| `scripts/game_camera.gd` | Caméra qui suit le héros, de biais et plongeante (angles de Dark Avenger), et tremble à l'impact |
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
- **Zones et lignes** : `reach(point, rayon)` réussit près du point **ou dès que
  sa ligne est franchie** (les niveaux avancent vers -Z) : courir sans passer
  au point exact ne bloque jamais le scénario. Les grilles ferment chaque
  partie tant que ses morts ne reposent pas. Pendant `reach`, `objective` est
  posé : le niveau montre une pointe d'or sur une colonne de lueur, et une
  flèche au bord de l'écran si le point est hors champ (`Level._update_guide`,
  `Hud.set_guide`). Ne jamais attendre un point précis sans ligne.
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
- **Niveaux fermés** : le héros ne doit jamais pouvoir sortir du décor, et le
  mur qui l'arrête doit se **voir** (clôture, mur, pilier), jamais un obstacle
  seul. `_reach_tests` (test) mesure, avec une capsule un peu plus mince que
  le héros (0,42) et toutes les grilles ouvertes, la zone qu'il atteint depuis
  le départ : elle doit rester bornée. Tout nouveau niveau y est ajouté. Un
  mur latéral qui s'arrête avant le mur du fond laisse un passage dans le
  coin : toujours les faire se rejoindre.
- **Obstacles** : `Level.grave_piece()` donne un obstacle aux décors verticaux
  de `Level.OBSTACLES` (stèles, arbres, lanternes…), à l'emprise de leur
  modèle ; `collide` faux pour ce qui bouge (les pierres de la Fossoyeuse).
- **Murs visibles** : tout obstacle (`solid`) doit avoir un objet visible au
  même endroit, jamais un mur invisible, et ne jamais être décalé derrière le
  mur qu'on voit (le corps traverserait le mur visible). `_visible_walls_tests`
  le vérifie sur chaque niveau. Un mur de fond placé derrière la caméra de
  départ la cache : le faire **bas** (`place(..., height_scale)`), comme les
  murets de la Chapelle et de l'Ossuaire.
- **Regroupement** : `Level.place()` regroupe les clôtures et les murs
  (`BATCHED`) en MultiMesh, une commande de dessin par partie de modèle ; elle
  renvoie alors un nœud vide. Sous terre, chaque mur reçoit un bloc de pierre
  de 8 de haut (`_caps`) : la caméra voit par-dessus les murs de 4. Les
  sphères et cylindres générés se font à basse résolution (16×8, 12 segments) :
  les valeurs par défaut (64×32) coûtaient 120 000 triangles à la Fosse.
- **Abords** (`scripts/scenery.gd`) : le terrain jouable est un plateau, et ce
  que la caméra voit autour est un décor défini selon le lieu, jamais du noir
  ni un horizon indéfini. Chaque niveau déclare `play_area` et, hors cimetière,
  `scenery` : `PIT` (la Fosse : terre et collines), `RIVER` (le moulin : fleuve
  animé et rive d'en face) ; le cimetière est le défaut (toits d'un faubourg en
  contrebas) ; sous terre ce sont les blocs sur les murs. **La caméra regarde à
  52° sous l'horizontale : elle ne voit jamais le ciel, seulement le sol
  alentour**, donc les abords sont du sol plus bas vu d'en haut, et tout objet
  lointain doit être bas. Les matériaux **luisent** (`_glow`) : sans lueur, ils
  retombent au noir sous la brume sur le téléphone.
- **Interface de jeu** : les boutons (`touch_controls.gd`) sont des disques
  sombres au double liseré, avec une icône dessinée en code (épée, bond de côté,
  fiole, pierre tombale pour le Repos, bulle, porte, ciseaux, livre, pause), un
  anneau de recharge pour l'esquive, un chiffre sur la fiole, un signal sur le
  carnet. La légende du bouton d'action est un `Label` (le texte dessiné dans la
  zone des boutons sortait en blocs). Le bouton pause (à côté du carnet, ou
  Échap/P) ouvre `PauseMenu` : Reprendre, volumes, Quitter après confirmation.
- **La carte en 3D** : un point du plan de `MapScene` (x, y) se pose dans le monde
  en (x, hauteur de l'étage, y) à l'échelle 0,03 (`MapWorld.to_world`). La
  caméra vise un point de la route (`scroll_to`) ; on choisit un point en
  projetant les positions à l'écran (`MapWorld.pick`, `WorldMap.screen_of` pour
  les essais). Les objets sont regroupés (MultiMesh) et luisent.
- **Relief de la carte** : `MapTerrain` calcule la hauteur du sol à partir du
  plan de `MapScene` ; le maillage est trop long à fabriquer sur le téléphone,
  il est fait d'avance (`godot --headless --path . -- --terrain`, fichier
  `assets/terrain/orvana_terrain.res`). Changer le relief, c'est changer
  `MapTerrain.VERSION` et relancer l'outil : le test vérifie la version, et
  que la route reste posée sur le relief.
- **Ville de la carte** : un quartier par voie de la route (donc par
  chapitre, `MapLife.zone_of`). Les bâtiments sont regroupés en MultiMesh par
  (modèle, quartier) : la caméra n'en dessine qu'une partie. Budget vérifié
  par le test (260 000 triangles en tout ; ~100 000 dessinés à l'écran). Les
  maisons KayKit n'ont pas de vitres dans l'atlas : de petites fenêtres sont
  posées sur la façade, d'après la porte (case 5,0) ; les tours, le château et
  la caserne ont leurs meurtrières (case 3,0, `MapCity.GLASS`).
- **Ville qui se souvient** : un quartier est « perdu » (brume noire, fenêtres
  éteintes, morts errants, corbeaux), « atteint » (un niveau fait ou « ici » ;
  une partie des fenêtres) ou « apaisé » (chapitre fini ; toutes). La brume se
  lève sous les yeux du joueur une seule fois (`Progress.seen`). Un niveau
  fait porte un brasier.
- **Mouvements de la carte** : travelling du fleuve au lieu « ici » en ouvrant
  la partie, recul depuis le niveau qu'on quitte (`WorldMap.arrived_from`),
  plongée derrière un corbeau en entrant. Pincement (ou Ctrl + molette) pour
  zoomer, double toucher dans le vide pour revenir « ici ». Les essais les
  coupent (`WorldMap.cinematics`), sauf la plongée, vérifiée à part.
- **Fiche du lieu** : chaque niveau de `WorldData` nomme ses morts (`dead`) ;
  la fiche montre leurs portraits, en silhouette s'ils sont inconnus.
- **Sceaux et fondations (carte)** : la route compte une voie par chapitre
  de la ville (`WorldData.ROUTE_CHAPTERS` = 10 : 3 + 3 + 3 + 1 voies, comme
  les actes du scénario) ; les deux derniers chapitres sont sous la ville
  (`UNDER_CHAPTERS`). Au milieu du rempart de chaque étage, un sceau
  (`WorldData.SEALS`) luit, puis se fend quand le dernier chapitre de l'étage
  est accompli. Sur la rive, la porte des fondations s'ouvre quand les quatre
  sont brisés. Rien de cela n'est jouable, et aucun nom n'y est écrit.
- **Le Repos découvert** : à la Grille, `hero.rite_enabled` est faux au début
  (pas de bouton REPOS) ; le premier mort est abattu, se relève, et c'est
  alors qu'Anselme enseigne le rite et que le bouton apparaît.
- **Grilles** : `add_gate(position, point_de_reprise)` ; au retour à un point
  de reprise, les grilles d'avant sont ouvertes.
- **Corps et obstacles** : la chute projette le corps ; il peut finir derrière
  une grille. Le rite se mesure donc avec `Enemy.distance_to_body()`, qui
  accepte aussi le point de chute.
- **Caméra et décor** : angles repris de Dark Avenger (`GameCamera`) : plongée
  de 52°, de biais (40° autour de la verticale), à 11 du buste du héros,
  soit près de 9,8 de haut ; elle se tient du côté +X et +Z du héros, et le
  chemin (-Z) monte en diagonale vers le haut à droite de l'écran. Le
  joystick et le clavier suivent ce biais (`TouchControls.view_yaw`), le
  joueur automatique donne des directions du monde. Un décor haut du côté
  de la caméra (mur droit, mur du bas) peut cacher le héros : le garder
  bas. Le héros ne doit jamais pouvoir passer derrière un décor plus haut
  qu'elle (les mausolées) : fermer ces recoins.
- **Nouveau niveau** : l'ajouter à `Main.LEVELS` ; il est déjà nommé dans
  `WorldData` (chapitre 1). Un autre chapitre demande d'abord d'écrire ses
  niveaux dans `WorldData`.
- **Textes à l'écran** : polices de `GameFonts` (CC0). La gothique n'a pas
  d'accents : la réserver aux titres, avec la police de texte en secours.
- **Sol** : `pave()` dessine tous les carreaux en un seul appel. Ne pas
  poser les carreaux un par un.
- **Entrées** : le jeu ne lit que `TouchControls.move`, `rite_held` et les
  signaux `attack_pressed`, `dodge_pressed`, `flask_pressed`, `book_pressed`
  et `rite_slot_pressed`.
- **Hasard du joueur automatique** : jamais l'identifiant interne d'un objet
  (`get_instance_id`) pour décider : il change dès qu'un objet de plus est
  créé (un élément d'interface suffit). Utiliser `Enemy.spawn_index`.
- **Caractéristiques du héros** : la progression les calcule
  (`Progress.hero_stats()`) et le niveau les applique avec
  `hero.apply_stats()`. Le héros ne lit jamais `Progress` lui-même.
- **Hasard des tests** : `Main` fixe la graine du hasard en mode test
  (`seed(...)`) : la Fosse tire au sort ses monticules et ses Dépouilles, et un
  test qui réussit une fois doit réussir toujours.
- **Tests et sauvegarde** : en mode test ou capture, `Main` écrit dans
  `user://essai.json`, jamais dans la vraie sauvegarde du joueur.

**Les rites de combat** (`RiteData`) : les attaques spéciales. Chaque Repos
donné allume une **braise** (cinq au plus, gardées par la sauvegarde) ; un
rite coûte une à trois braises, rien ne se recharge avec le temps. Trois
rites portés, un bouton chacun sur un quart de cercle autour de FRAPPER, tous
à la même distance (`TouchControls.SLOT_ARC`, disposition choisie par
l'auteur : l'arc serré, l'esquive tout en bas à gauche de FRAPPER, REPOS à
gauche de l'arc) ; icône dessinée en code, coût en losanges, **nom
dessous** ; clavier 1, 2, 3. `TouchControls.layout_problems()` vérifie (test)
qu'aucun bouton ne se chevauche, ne sort de l'écran, ni ne touche le nom d'un
rite. **Les rites portés se choisissent sur la carte**, dans la fiche du
lieu, au-dessus d'« Entrer » ; en plein niveau, le carnet les montre mais ne
les change plus (`SkillBook.in_level`). Neuf rites : Glas
(onde qui renverse), Linceul (tourbillon), Cortège (ruée qui traverse),
Tombée (bond, impact), Requiem (garde fendue : le coup suivant abat), Litanie
(cinq coups, le dernier abat), Cierge (zone où les corps ne se relèvent pas),
Absoute (lame qui file), Rappel (un mort apaisé combat pour le héros, après
le Sceau des Armes). Chacun s'ouvre avec un niveau (`unlock`), se présente
une fois sur la carte avec son animation (`WorldMap.show_next_rite`), se
porte dans le carnet (onglet Combat). Un rite n'est pas interrompu par les
coups (il blesse quand même) ; la ruée et le bond sont intouchables et
traversent les morts. Renverser un boss ne l'abat pas : il encaisse
`boss_damage`. Valeurs dans `rites.gd`, gestes dans `hero_classes.gd`
(`rite_animations`). Le test vérifie chaque rite dans l'arène ; le joueur
automatique les lance quand la situation s'y prête.

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

Le build publie aussi **une release par version** (`releases/tag/vX.Y.Z`,
titre « Oathfall X.Y.Z », APK `oathfall-X.Y.Z.apk`, commits depuis la version
précédente), gardée pour que l'auteur retrouve chaque version. Un envoi sans
changement de numéro remplace l'APK de la release existante : **tout envoi qui
change le jeu augmente la version.**

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
