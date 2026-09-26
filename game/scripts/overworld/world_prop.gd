extends Sprite2D
class_name WorldProp
## Every object uses a source-region anchor and a metadata-defined tile footprint.
static func create(item: Dictionary) -> WorldProp:
	var data := WorldCatalog.asset(str(item.asset))
	var sprite := WorldProp.new()
	sprite.name = str(item.asset)
	sprite.texture = load(str(data.sheet))
	sprite.region_enabled = true
	sprite.region_rect = CharacterPresentation.rect(data.region)
	sprite.region_filter_clip_enabled = true
	sprite.centered = false
	sprite.offset = -Vector2(float(data.anchor[0]),float(data.anchor[1]))
	var factor := float(data.width) / float(data.region[2])
	sprite.scale = Vector2.ONE * factor
	sprite.position = Vector2(WorldCatalog.tile(item.tile) * 16) + Vector2(8,8)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if item.asset == "bridge": sprite.z_index = -9
	return sprite
