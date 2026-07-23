# Intégrer un mini-jeu au multijoueur local

Ce guide explique comment transformer un mini-jeu solo en mini-jeu compatible avec tous les joueurs inscrits dans le lobby.

Le principe essentiel est :

> Un mini-jeu ne lit jamais les touches physiques. Il reçoit un `LocalPlayer` et interprète les commandes génériques de `player.input` selon son propre gameplay.

Ainsi, Action 1 peut signifier « sauter » dans un jeu, « attraper » dans un autre et « valider » dans un troisième.

## Architecture

Le système sépare trois responsabilités :

```text
PlayerRegistry
    Qui joue ?

PlayerInputRouter
    Quel profil physique demande quelle commande ?

PlayerInputState
    Que veut faire ce joueur pendant ce tick ?
```

Le flux complet est :

```text
Clavier ou souris
        ↓
PlayerInputRouter traduit l'événement
        ↓
PlayerRegistry retrouve le joueur du profil
        ↓
PlayerInputRouter actualise son PlayerInputState
        ↓
Le mini-jeu lit player.input
```

### `PlayerRegistry`

Autoload responsable uniquement des joueurs :

```gdscript
PlayerRegistry.get_players()
PlayerRegistry.get_player_for_profile(profile_id)
PlayerRegistry.join_profile(profile_id)
PlayerRegistry.leave_profile(profile_id)
PlayerRegistry.clear_players()
```

Il ne connaît aucune touche et ne traduit aucun événement.

### `PlayerInputRouter`

Autoload responsable des périphériques :

- détecte le profil qui rejoint ;
- sépare les deux zones du clavier ;
- gère les positions physiques AZERTY ;
- transforme la souris en direction normalisée ;
- actualise l'état d'entrée de chaque joueur.

Les mini-jeux ne doivent normalement jamais appeler ce routeur. Le lobby l'utilise seulement pour ouvrir ou fermer les inscriptions :

```gdscript
PlayerInputRouter.set_joining_enabled(true)
```

### `PlayerInputState`

Petit objet appartenant à chaque `LocalPlayer`. C'est la seule API d'entrée lue par les mini-jeux.

## API générique des commandes

Chaque joueur expose :

```gdscript
player.input.direction

player.input.action_1_pressed
player.input.action_1_just_pressed

player.input.action_2_pressed
player.input.action_2_just_pressed
```

### `direction`

Vecteur normalisé entre `-1` et `1` :

```text
Vector2(-1, 0) : gauche
Vector2(1, 0)  : droite
Vector2(0, -1) : haut
Vector2(0, 1)  : bas
Vector2.ZERO    : aucune direction
```

Une diagonale est limitée à une longueur de `1` afin de ne pas être plus rapide.

Un jeu de profil utilisera généralement seulement :

```gdscript
var horizontal_direction := player.input.direction.x
```

### Actions maintenues

Les propriétés `pressed` restent vraies tant que le bouton est maintenu :

```gdscript
if player.input.action_1_pressed:
	continue_action()
```

### Actions ponctuelles

Les propriétés `just_pressed` ne sont vraies que pendant le premier tick physique :

```gdscript
if player.input.action_2_just_pressed:
	trigger_action_once()
```

Lisez les commandes ponctuelles dans `_physics_process()`. Le routeur les efface à la fin du tick physique.

## Correspondance physique actuelle

| Profil | Direction | Action 1 | Action 2 |
|---|---|---|---|
| Clavier gauche | ZQSD | Maj gauche | `<` |
| Clavier droit | Flèches | `/` | `!` |
| Souris | Zones des bords | Clic gauche | Clic droit |

Cette correspondance appartient au routeur. Un mini-jeu ne doit pas la reproduire.

## Transformer un acteur solo

Voici un acteur solo classique :

```gdscript
extends CharacterBody2D

@export var speed := 250.0


func _physics_process(_delta: float) -> void:
	var movement := Input.get_axis("move_left", "move_right")
	velocity.x = movement * speed

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = -450.0

	if Input.is_action_just_pressed("dash"):
		start_dash()

	move_and_slide()
```

### Étape 1 : recevoir un joueur

```gdscript
var player: LocalPlayer


func setup(assigned_player: LocalPlayer) -> void:
	player = assigned_player
```

### Étape 2 : choisir le sens des actions génériques

Pour ce jeu précis :

```text
direction.x = déplacement horizontal
Action 1    = saut
Action 2    = dash
```

Cette décision reste locale au mini-jeu.

### Étape 3 : remplacer les appels à `Input`

```gdscript
func _physics_process(_delta: float) -> void:
	if player == null:
		return

	velocity.x = player.input.direction.x * speed

	if player.input.action_1_pressed and is_on_floor():
		velocity.y = -450.0

	if player.input.action_2_just_pressed:
		start_dash()

	move_and_slide()
```

L'acteur ne connaît plus ZQSD, les flèches ou la souris.

## Créer un acteur par joueur

La scène principale du mini-jeu récupère la liste globale :

```gdscript
const ACTOR_SCENE := preload("res://mon_jeu/actor.tscn")


func _ready() -> void:
	for player in PlayerRegistry.get_players():
		spawn_actor(player)
```

Puis elle associe chaque instance à son joueur :

```gdscript
func spawn_actor(player: LocalPlayer) -> void:
	var actor = ACTOR_SCENE.instantiate()
	actor.setup(player)
	actor.position = get_spawn_position(player)
	add_child(actor)
```

L'objet `LocalPlayer` reste le même pendant la session. Son `input` est actualisé automatiquement par le routeur.

## Supporter un, deux ou trois joueurs

Ne supposez jamais un nombre fixe de joueurs :

```gdscript
func spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	var screen_width := get_viewport_rect().size.x

	for index in players.size():
		var player := players[index]
		var x := screen_width * float(index + 1) / float(players.size() + 1)
		spawn_actor_at(player, Vector2(x, 300.0))
```

Cette formule répartit automatiquement les acteurs disponibles.

## Scores et résultats

Utilisez `player.id` pour associer un résultat au bon joueur :

```gdscript
var scores: Dictionary[int, int] = {}


func add_point(player: LocalPlayer) -> void:
	scores[player.id] = scores.get(player.id, 0) + 1
```

Autres informations disponibles :

```gdscript
player.display_name
player.color
player.profile_id
player.profile_name
```

`profile_id` peut servir à l'affichage, mais jamais à choisir les touches dans le mini-jeu.

## Connexions et déconnexions

Si les joueurs sont fixes pendant le mini-jeu, un appel à `get_players()` dans `_ready()` suffit.

Pour réagir aussi aux changements :

```gdscript
func _ready() -> void:
	PlayerRegistry.players_changed.connect(_sync_players)
	_sync_players(PlayerRegistry.get_players())


func _exit_tree() -> void:
	if PlayerRegistry.players_changed.is_connected(_sync_players):
		PlayerRegistry.players_changed.disconnect(_sync_players)
```

La fonction `_sync_players()` crée les acteurs manquants et supprime ceux dont l'identifiant a disparu.

La feature `features/main_menu_players/player_arena.gd` en fournit un exemple complet.

## Tester une scène directement

Pendant le développement uniquement, une scène lancée sans lobby peut inscrire un profil de test :

```gdscript
func _ready() -> void:
	if PlayerRegistry.get_players().is_empty():
		PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)

	spawn_all_players()
```

N'activez pas les inscriptions depuis chaque mini-jeu. Le lobby est responsable de :

```gdscript
PlayerInputRouter.set_joining_enabled(true)
```

## Ajouter une nouvelle commande universelle

Si deux actions ne suffisent plus :

1. ajouter l'état générique dans `PlayerInputState` ;
2. associer une entrée pour chaque profil dans `PlayerInputRouter` ;
3. tester appui, maintien et relâchement dans `test.gd` ;
4. documenter la nouvelle commande ;
5. lire uniquement cet état générique dans les mini-jeux.

N'ajoutez jamais une touche physique directement dans un script de gameplay.

## Checklist

- L'acteur reçoit un `LocalPlayer` avec `setup()`.
- Le gameplay lit uniquement `player.input`.
- Action 1 et Action 2 sont interprétées localement par le mini-jeu.
- Aucun nom comme `jump` ou `dash` n'existe dans l'API multijoueur.
- La scène fonctionne avec un, deux et trois joueurs.
- Les `just_pressed` sont lus dans `_physics_process()`.
- Les scores utilisent `player.id`.
- Les points d'apparition s'adaptent au nombre de joueurs.
- Une déconnexion ne laisse pas d'acteur orphelin si elle est autorisée.

## Exemple de référence

```text
features/main_menu_players/player_arena.gd
    récupère et synchronise les LocalPlayer

features/main_menu_players/player_cube.gd
    interprète Action 1 comme saut et Action 2 comme dash
```

Cette séparation est le modèle recommandé pour tous les futurs mini-jeux.
