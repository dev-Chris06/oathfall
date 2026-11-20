class_name UpdateCheck
extends Node
## Cherche une version plus récente du jeu sur la page de téléchargement
## (la publication « dev » du dépôt). Les notes de cette page commencent par
## « Version x.y.z. », écrites par le build automatique.

## Résultat : `state` vaut "ok" (à jour), "new" (une version plus récente,
## `remote`) ou "error" (`remote` est vide).
signal finished(state: String, remote: String)

const API := "https://api.github.com/repos/dev-Chris06/oathfall/releases/tags/dev"
## Le fichier à télécharger : le navigateur du téléphone s'en charge.
const DOWNLOAD := "https://github.com/dev-Chris06/oathfall/releases/download/dev/oathfall-debug.apk"

var _request: HTTPRequest


## Lance la recherche ; `finished` arrive ensuite.
func start() -> void:
	if _request != null:
		_request.queue_free()
	_request = HTTPRequest.new()
	_request.timeout = 12.0
	add_child(_request)
	_request.request_completed.connect(_on_completed)
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: Oathfall"])
	if _request.request(API, headers) != OK:
		finished.emit("error", "")


static func local_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## La version écrite au début des notes de la page, ou "".
static func version_from_notes(notes: String) -> String:
	var regex := RegEx.create_from_string("Version (\\d+(?:\\.\\d+)*)")
	var found := regex.search(notes)
	return found.get_string(1) if found != null else ""


## Vrai si `remote` est plus récente que `local` (« 0.26.0 » contre « 0.25.3 »).
static func is_newer(remote: String, local: String) -> bool:
	var a := remote.split(".")
	var b := local.split(".")
	for i in maxi(a.size(), b.size()):
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return false


static func open_download() -> void:
	OS.shell_open(DOWNLOAD)


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		finished.emit("error", "")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		finished.emit("error", "")
		return
	var remote := version_from_notes(str((parsed as Dictionary).get("body", "")))
	if remote == "":
		finished.emit("error", "")
	elif is_newer(remote, local_version()):
		finished.emit("new", remote)
	else:
		finished.emit("ok", remote)
