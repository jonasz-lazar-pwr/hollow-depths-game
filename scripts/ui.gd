extends CanvasLayer

# Referencja do etykiety drabin
@onready var ladder_label: Label = $LadderCountLabel
# Referencja do etykiety HP
@onready var health_label: Label = $HealthLabel
# Referencja do gracza
@onready var player: Node = get_tree().get_first_node_in_group("player")


func _ready():
	# Sprawdź, czy gracz został znaleziony
	if player:
		# --- Połączenie sygnału ekwipunku (bez zmian) ---
		if not player.inventory_updated.is_connected(_on_player_inventory_updated):
			player.inventory_updated.connect(_on_player_inventory_updated)

		# Spróbuj od razu zaktualizować etykietę drabin (bez zmian)
		if "inventory" in player:
			if has_method("_on_player_inventory_updated"):
				_on_player_inventory_updated(player.inventory)
		else:
			ladder_label.text = "Drabiny: ..."

		# ---> POŁĄCZ SYGNAŁ HP GRACZA Z FUNKCJĄ W TYM SKRYPCIE <---
		if not player.health_updated.is_connected(_on_player_health_updated):
			player.health_updated.connect(_on_player_health_updated)

		# ---> SPRÓBUJ NATYCHMIAST ZAKTUALIZOWAĆ ETYKIETĘ HP <---
		if "current_hp" in player and "max_hp" in player:
			if has_method("_on_player_health_updated"):
				_on_player_health_updated(player.current_hp, player.max_hp)
		else:
			# Ustaw tekst tymczasowy, jeśli HP nie jest dostępne
			if is_instance_valid(health_label):
				health_label.text = "HP: Ładowanie..."

	else:
		# Nie znaleziono gracza (bez zmian)
		printerr("UI Error: Player node not found in group 'player'. Cannot update UI.")
		ladder_label.text = "BŁĄD Gracza!"
		# ---> UKRYJ LUB POKAŻ BŁĄD W ETYKIECIE HP <---
		if is_instance_valid(health_label):
			# POPRAWIONE WCIĘCIE PONIŻEJ (zakładając użycie tabulatorów)
			health_label.text = "BŁĄD Gracza!"


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


# Ta funkcja jest wywoływana, gdy sygnał 'health_updated' od gracza dotrze
func _on_player_health_updated(new_hp: float, max_hp_value: float):
	# Sprawdź, czy etykieta HP istnieje i jest poprawna
	if not is_instance_valid(health_label):
		printerr("UI Error: HealthLabel node is not valid!")
		return

	# Zaktualizuj tekst etykiety w formacie "AktualneHP/MaksymalneHP"
	# Używamy int() dla ładniejszego wyświetlania liczb całkowitych
	health_label.text = "HP: %d/%d" % [int(new_hp), int(max_hp_value)]
