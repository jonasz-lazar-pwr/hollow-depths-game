class_name InventoryGridItemUI extends Control

var item: InventoryItem:
	set = set_item

var count: int = 1:
	set = set_count

@onready var icon: TextureRect = $Icon
@onready var countLabel: Label = $Icon/Count
@onready var tooltip: CanvasLayer = $Tooltip 
@onready var tooltip_container: PanelContainer = $Tooltip/Container # Dodajemy referencję do PanelContainer
@onready var tooltipTitle: Label = $Tooltip/Container/MarginContainer/VBoxContainer/Title
@onready var tooltipText: RichTextLabel = $Tooltip/Container/MarginContainer/VBoxContainer/Text
# @onready var vbox_container_tooltip: VBoxContainer = $Tooltip/Container/MarginContainer/VBoxContainer # Ta referencja może nie być już potrzebna do debugowania rozmiaru

signal request_select(item)


func set_item(i: InventoryItem):
	item = i
	if is_inside_tree():
		_update_item_content() # Zmieniamy nazwę, aby odróżnić od aktualizacji UI

func set_count(c: int):
	count = c
	if is_inside_tree() and is_instance_valid(countLabel): # Dodatkowe sprawdzenie dla countLabel
		countLabel.text = str(count)
		if count == 0:
			countLabel.hide()
		else:
			countLabel.show()

# Funkcja do ustawiania zawartości tekstowej tooltipa
func _update_item_content():
	if not is_instance_valid(icon) or \
	   not is_instance_valid(tooltipTitle) or \
	   not is_instance_valid(tooltipText) or \
	   not is_instance_valid(countLabel):
		print_rich("[color=orange]InventoryGridItemUI: One or more UI elements not ready in _update_item_content().[/color]")
		return

	if not item or not item.item_type:
		icon.texture = null
		tooltipTitle.text = ""
		tooltipText.text = " " # RichTextLabel nie lubi pustego stringa, jeśli używamy BBCode
		countLabel.text = "0"
		countLabel.hide()
		return
	
	icon.texture = item.item_type.texture
	tooltipTitle.text = item.name
	tooltipText.text = item.item_type.description # Upewnij się, że description nie jest null
	
	# Aktualizujemy countLabel tutaj też, na wszelki wypadek
	if is_instance_valid(countLabel):
		countLabel.text = str(count)
		countLabel.visible = count > 0

func _ready():
	# Sprawdzenie, czy wszystkie @onready zmienne są zainicjowane
	if not is_instance_valid(tooltip) or \
	   not is_instance_valid(tooltip_container) or \
	   not is_instance_valid(tooltipTitle) or \
	   not is_instance_valid(tooltipText) or \
	   not is_instance_valid(icon) or \
	   not is_instance_valid(countLabel):
		print_rich("[color=red]InventoryGridItemUI: CRITICAL - Not all @onready nodes are valid in _ready(). Check paths![/color]")
		return # Nie kontynuuj, jeśli brakuje kluczowych węzłów

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	_update_item_content() # Ustaw zawartość, ale tooltip jest jeszcze ukryty

	# === KLUCZOWA POPRAWKA Z TWOJEGO KODU ===
	# Ukrywamy tooltip na starcie, aby nie był widoczny od razu
	tooltip.hide() 
	# === KONIEC KLUCZOWEJ POPRAWKI ===


func _on_mouse_entered():
	if not item or not item.item_type: # Nie pokazuj tooltipa dla pustych slotów
		return

	if is_instance_valid(tooltip) and is_instance_valid(tooltip_container):
		# 1. Upewnij się, że teksty są aktualne
		_update_item_content()

		# 2. Pokaż CanvasLayer
		tooltip.show()

		# 3. === KLUCZOWA ZMIANA: POCZEKAJ JEDNĄ KLATKĘ ===
		# Dajemy silnikowi czas na przetworzenie zmian (np. obliczenie rozmiaru RichTextLabel)
		# po tym, jak tooltip stał się widoczny i teksty zostały ustawione.
		await get_tree().process_frame 
		# === KONIEC KLUCZOWEJ ZMIANY ===

		# 4. Teraz, gdy kontrolki wewnętrzne miały szansę się przeliczyć,
		#    zresetuj rozmiar głównego kontenera tooltipa.
		tooltip_container.reset_size()

func _on_mouse_exited():
	if is_instance_valid(tooltip):
		tooltip.hide()
