extends Control

## Minimal script used by BattleWindow to reference slot UI nodes.
func reset() -> void:
	var name_label := get_node_or_null("Name")
	if name_label:
		name_label.text = ""
	var hp := get_node_or_null("HP")
	if hp:
		hp.value = 0
	var cd := get_node_or_null("CD")
	if cd:
		cd.value = 0
	var pop := get_node_or_null("DmgPop")
	if pop:
		pop.text = ""
		pop.modulate.a = 0.0
