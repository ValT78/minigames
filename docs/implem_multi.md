# Intégrer un mini-jeu au multijoueur local

Ce guide explique comment transformer un mini-jeu solo local en mini-jeu compatible avec tous les joueurs inscrits dans le lobby.

Le principe essentiel est le suivant :

> Un mini-jeu ne lit jamais les touches physiques. Il reçoit un `LocalPlayer` et lit les commandes normalisées dans `player.input`.

Ainsi, le même code de gameplay fonctionne pour ZQSD, les flèches et la souris.

## Architecture générale

Le système est séparé en deux niveaux :

```text
Clavier et souris
        ↓
PlayerRegistry traduit les événements physiques
        ↓
LocalPlayer contient l'identité d'un joueur
        ↓
PlayerInput expose les commandes normalisées
        ↓
Le mini-jeu déplace un acteur sans connaître son périphérique
```

Les fichiers importants sont :

- `player_registry.gd` : conserve les joueurs et traduit les périphériques ;
- `local_player.gd` : contient l'identité, la couleur et l'input d'un joueur ;
- `player_input.gd` : définit les commandes disponibles pour tous les profils ;
- `features/player_cubes/` : exemple complet d'une feature utilisant cette API.

`PlayerRegistry` est un Autoload. Il reste donc vivant pendant les changements de scène.

## Commandes disponibles

Chaque `LocalPlayer` possède un objet `input` :

```gdscript
player.input.movement
player.input.jump_pressed
player.input.jump_just_pressed
player.input.dash_just_pressed
```

### `movement`

`movement` est un `Vector2` normalisé :

```text
Vector2(-1, 0) : gauche
Vector2(1, 0)  : droite
Vector2(0, -1) : haut
Vector2(0, 1)  : bas
Vector2.ZERO    : aucune direction
```

La longueur maximale du vecteur vaut `1`. Une diagonale n'est donc pas plus rapide qu'une direction simple.

### `jump_pressed`

Reste vrai tant que le bouton de saut est maintenu. Utilisez-le pour une action qui doit se répéter ou continuer :

```gdscript
if player.input.jump_pressed and is_on_floor():
	jump()
```

### `jump_just_pressed`

N'est vrai que pendant le premier tick physique de l'appui :

```gdscript
if player.input.jump_just_pressed:
	open_door()
```

### `dash_just_pressed`

Représente une demande ponctuelle de dash :

```gdscript
if player.input.dash_just_pressed:
	start_dash()
```

Les commandes `just_pressed` doivent être lues dans `_physics_process()`. Elles sont effacées à la fin du tick physique.

## Transformer un acteur solo

Imaginons un personnage solo qui lit directement les actions Godot :

```gdscript
extends CharacterBody2D

@export var speed := 250.0


func _physics_process(_delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = -450.0

	if Input.is_action_just_pressed("dash"):
		start_dash()

	move_and_slide()
```

La première modification consiste à lui donner un `LocalPlayer` :

```gdscript
extends CharacterBody2D

@export var speed := 250.0

var player: LocalPlayer


func setup(assigned_player: LocalPlayer) -> void:
	player = assigned_player
```

Le gameplay lit ensuite `player.input` :

```gdscript
func _physics_process(_delta: float) -> void:
	if player == null:
		return

	velocity.x = player.input.movement.x * speed

	if player.input.jump_pressed and is_on_floor():
		velocity.y = -450.0

	if player.input.dash_just_pressed:
		start_dash()

	move_and_slide()
```

Le personnage ne contient plus aucune référence à ZQSD, aux flèches ou à la souris.

## Créer un acteur par joueur

La scène principale du mini-jeu récupère les joueurs inscrits :

```gdscript
const ACTOR_SCENE := preload("res://chemin/actor.tscn")


func _ready() -> void:
	for player in PlayerRegistry.get_players():
		spawn_actor(player)
```

Elle instancie ensuite un acteur pour chacun :

```gdscript
func spawn_actor(player: LocalPlayer) -> void:
	var actor = ACTOR_SCENE.instantiate()
	actor.setup(player)
	actor.position = get_spawn_position(player)
	add_child(actor)
```

L'acteur conserve la référence vers son `LocalPlayer`. Son objet `input` est mis à jour automatiquement par le registre global.

Il n'est pas nécessaire de rechercher le joueur à chaque frame.

## Choisir les points d'apparition

Ne supposez pas qu'il existe toujours trois joueurs. Calculez les apparitions à partir de la liste reçue :

```gdscript
func spawn_all_players() -> void:
	var players := PlayerRegistry.get_players()
	var screen_width := get_viewport_rect().size.x

	for index in players.size():
		var player := players[index]
		var x := screen_width * float(index + 1) / float(players.size() + 1)
		spawn_actor_at(player, Vector2(x, 300.0))
```

Cette formule répartit correctement un, deux ou trois joueurs.

## Identifier les résultats

Utilisez `player.id` pour rattacher un score ou un résultat à un joueur :

```gdscript
var scores: Dictionary[int, int] = {}


func add_point(player: LocalPlayer) -> void:
	scores[player.id] = scores.get(player.id, 0) + 1
```

Les autres informations utiles sont :

```gdscript
player.display_name
player.color
player.profile_id
player.profile_name
```

`profile_id` peut servir à afficher le périphérique, mais ne doit pas servir à choisir les touches dans le mini-jeu.

## Réagir aux connexions et déconnexions

Normalement, les joueurs rejoignent dans le lobby puis restent identiques pendant un mini-jeu. Dans ce cas, un appel à `get_players()` dans `_ready()` suffit.

Si une scène doit également réagir aux départs, elle peut écouter le signal :

```gdscript
func _ready() -> void:
	PlayerRegistry.players_changed.connect(_sync_players)
	_sync_players(PlayerRegistry.get_players())


func _exit_tree() -> void:
	if PlayerRegistry.players_changed.is_connected(_sync_players):
		PlayerRegistry.players_changed.disconnect(_sync_players)
```

La fonction `_sync_players()` crée les acteurs manquants et supprime ceux dont l'identifiant n'est plus présent.

`features/player_cubes/player_arena.gd` fournit un exemple complet de cette synchronisation.

## Tester un mini-jeu sans passer par le lobby

Pendant le développement uniquement, une scène lancée directement peut créer un joueur de test :

```gdscript
func _ready() -> void:
	if PlayerRegistry.get_players().is_empty():
		PlayerRegistry.join_profile(PlayerRegistry.KEYBOARD_LEFT)

	spawn_all_players()
```

Évitez ce fallback dans la version finale : le lobby doit normalement être responsable des inscriptions.

## Ajouter une nouvelle commande universelle

Si un mini-jeu a besoin d'une nouvelle commande, elle doit exister pour tous les profils.

La procédure est :

1. ajouter l'état abstrait dans `PlayerInput` ;
2. associer une entrée physique pour chaque profil dans `PlayerRegistry` ;
3. tester l'appui et le relâchement dans `test.gd` ;
4. utiliser uniquement le nouvel état abstrait dans le mini-jeu.

N'ajoutez pas directement une touche physique dans un script de mini-jeu. Sinon le jeu ne fonctionnera plus automatiquement avec les autres profils.

## Checklist d'intégration

Avant de considérer un mini-jeu comme compatible :

- aucun script de gameplay ne lit directement les touches physiques ;
- chaque acteur reçoit un `LocalPlayer` avec une fonction `setup()` ;
- la scène fonctionne avec un, deux et trois joueurs ;
- les commandes `just_pressed` sont lues dans `_physics_process()` ;
- les couleurs ou noms proviennent du `LocalPlayer` ;
- les scores sont associés à `player.id` ;
- les points d'apparition s'adaptent au nombre de joueurs ;
- une déconnexion ne laisse pas d'acteur orphelin si elle est autorisée dans la scène.

## Exemple de référence

Pour voir l'ensemble du branchement dans du code fonctionnel :

```text
features/player_cubes/player_arena.gd
        récupère et synchronise les joueurs

features/player_cubes/player_cube.gd
        reçoit un LocalPlayer et lit player.input
```

Cette séparation est le modèle recommandé pour les futurs mini-jeux.
