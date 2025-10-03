extends Resource
## Tracks the pool of available eggs that can be assigned to new brood cells.
class_name QueenEggs

@export var eggs: int = 0

func take(amount: int) -> int:
    ## Removes up to `amount` eggs from the pool and returns how many were
    ## actually assigned.
    if amount <= 0:
        return 0
    var taken: int = min(amount, eggs)
    eggs -= taken
    return taken
