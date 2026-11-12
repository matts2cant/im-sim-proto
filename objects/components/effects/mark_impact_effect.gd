class_name MarkImpactEffect
extends Effect
## Leaves a mark on the entity's ImpactMarks where a RAY stimulus hit it (EffectContext.data
## `position` and `normal`). Other shapes carry no hit point and leave nothing.


func apply(ctx: EffectContext) -> void:
	var marks := ImpactMarks.of(ctx.entity)
	if marks == null or not ctx.data.has("position"):
		return
	marks.add_mark(ctx.data["position"] as Vector3, ctx.data.get("normal", Vector3.ZERO) as Vector3)


func can_apply(ctx: EffectContext) -> bool:
	return ImpactMarks.of(ctx.entity) != null
