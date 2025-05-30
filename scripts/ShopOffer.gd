# res://scripts/ShopOffer.gd
class_name ShopOffer extends Resource

enum RewardType { UNLOCK_DIGGING, INCREASE_MAX_HP, PICKAXE_30, OTHER }

@export var offer_name: String = "Offer Name"
@export_multiline var description: String = "Offer description."

@export var cost_item: InventoryItemType
@export var cost_amount: int = 1 # Jeśli cost_item jest null, to jest to koszt w monetach

@export var reward_type: RewardType = RewardType.OTHER
# reward_string_data: może być używane jako klucz identyfikujący typ ulepszenia, np. "PICKAXE_LEVEL_PROGRESS"
@export var reward_string_data: String = "" 
# reward_float_data: wartość nagrody, np. nowy mnożnik obrażeń dla kilofa
@export var reward_float_data: float = 0.0  

@export var unique_id: String = "unique_offer_id_for_this_specific_offer" # ID tej konkretnej oferty/poziomu

# NOWE POLA:
@export var display_icon: Texture2D # Ikona do pokazania dla tej konkretnej oferty (np. ikona kilofa Lvl 2)
@export var level_number: int = 0 # Numer poziomu, który ta oferta odblokowuje (1 dla Lvl 1, 2 dla Lvl 2 itd.)
								  # 0 może oznaczać, że nie dotyczy/jednorazowe ulepszenie
