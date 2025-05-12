# res://scripts/shop/ShopOffer.gd
class_name ShopOffer extends Resource

enum RewardType { UNLOCK_DIGGING, INCREASE_MAX_HP, OTHER } # Dodajmy przykład

@export var offer_name: String = "Offer Name"
@export_multiline var description: String = "Offer description."

@export var cost_item: InventoryItemType
@export var cost_amount: int = 1

@export var reward_type: RewardType = RewardType.OTHER

# Zamiast Variant, użyjmy czegoś bardziej konkretnego lub pogrupujmy
# Jeśli dla UNLOCK_DIGGING to zawsze String (nazwa bloku/ulepszenia):
@export var reward_string_data: String = "" # Dla nazw, ID itp.
# Jeśli dla INCREASE_MAX_HP to zawsze float:
@export var reward_float_data: float = 0.0 # Dla wartości liczbowych

# Możesz też zrobić bardziej złożoną strukturę, np. Dictionary, ale to trudniej exportować ładnie.
# Na razie powyższe powinno rozwiązać błąd eksportu.
# W kodzie będziesz musiał wybrać, którego pola użyć na podstawie reward_type:
# if offer.reward_type == RewardType.UNLOCK_DIGGING:
#    var upgrade_name = offer.reward_string_data
# elif offer.reward_type == RewardType.INCREASE_MAX_HP:
#    var hp_bonus = offer.reward_float_data

@export var unique_id: String = "unique_offer_id"
