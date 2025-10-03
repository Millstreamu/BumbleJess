extends RefCounted
## Enumerates the specialized cell types that can appear on the hex grid.
class_name CellType

enum Type {
    QUEEN_SEAT,
    WAX,
    VAT,
    STORAGE,
    GATHERING,
    GUARD,
    HALL,
    BROOD,
    EMPTY,
}

static func buildable_types() -> Array[int]:
    return [
        Type.WAX,
        Type.VAT,
        Type.STORAGE,
        Type.GATHERING,
        Type.GUARD,
        Type.HALL,
    ]

static func to_display_name(cell_type: int) -> String:
    match cell_type:
        Type.QUEEN_SEAT:
            return "Queen Seat"
        Type.WAX:
            return "Wax"
        Type.VAT:
            return "Vat"
        Type.STORAGE:
            return "Storage"
        Type.GATHERING:
            return "Gathering"
        Type.GUARD:
            return "Guard"
        Type.HALL:
            return "Hall"
        Type.BROOD:
            return "Brood"
        Type.EMPTY:
            return "Empty"
        _:
            return "Unknown"

static func is_specialized(cell_type: int) -> bool:
    return cell_type != Type.EMPTY
