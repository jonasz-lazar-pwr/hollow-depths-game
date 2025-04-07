extends CanvasLayer

# Referencja do etykiety
@onready var ladder_label: Label = $LadderCountLabel
# Referencja do gracza
@onready var player: Node = get_tree().get_first_node_in_group("player")

func _ready():
	# Spróbujemy ustawić wartość od razu, zamiast "..."

	# Sprawdź, czy gracz został znaleziony
	if player:
		# Połącz sygnał gracza z naszą funkcją aktualizującą UI
		# Sprawdź dla pewności, czy już nie jest połączony
		# Upewnij się, że funkcja _on_player_inventory_updated ISTNIEJE PONIŻEJ
		if not player.inventory_updated.is_connected(_on_player_inventory_updated):
			player.inventory_updated.connect(_on_player_inventory_updated)

		# Spróbuj od razu zaktualizować etykietę na podstawie BIEŻĄCEGO stanu ekwipunku gracza.
		if "inventory" in player:
			# Wywołaj funkcję aktualizującą UI z aktualną wartością.
			# Upewnij się, że funkcja _on_player_inventory_updated ISTNIEJE PONIŻEJ
			_on_player_inventory_updated(player.inventory)
		else:
			# Jeśli 'inventory' jeszcze nie istnieje, ustaw tymczasowy tekst.
			# Sygnał z _ready() gracza wkrótce to poprawi.
			ladder_label.text = "Drabiny: ..." # Tekst tymczasowy

	else:
		# Nie znaleziono gracza
		printerr("UI Error: Player node not found in group 'player'. Cannot update ladder count.")
		ladder_label.text = "BŁĄD Gracza!"

# --------------------------------------------------
# WAŻNE: UPEWNIJ SIĘ, ŻE TA FUNKCJA ISTNIEJE W PLIKU!
# --------------------------------------------------
# Ta funkcja jest wywoływana, gdy sygnał 'inventory_updated' od gracza dotrze
func _on_player_inventory_updated(current_inventory: Dictionary):
	# Sprawdź, czy label istnieje (na wypadek gdyby coś poszło nie tak w _ready)
	if not is_instance_valid(ladder_label):
		printerr("UI Error: LadderCountLabel is not valid!")
		return

	# Pobierz liczbę drabin ze słownika
	var count = current_inventory.get("ladder", 0)
	# Zaktualizuj tekst etykiety
	ladder_label.text = "Drabiny: %d" % count
# --------------------------------------------------
