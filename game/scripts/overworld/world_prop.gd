extends Sprite2D
class_name WorldProp
## Every object uses a source-region anchor and a metadata-defined tile footprint.
const ROOF_SHADER := preload("res://scripts/overworld/roof_variant.gdshader")
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
	# Painted 1254px source: filtered minification keeps it clean at 2x-6x output.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Variants reuse another building's art until authored art exists: they
	# may be mirrored and re-roofed (see environment.json "placeholder").
	sprite.flip_h = bool(data.get("flip_h", false))
	if data.has("roof"):
		var roof := ShaderMaterial.new()
		roof.shader = ROOF_SHADER
		for key in data.roof:
			roof.set_shader_parameter(key, float(data.roof[key]))
		sprite.material = roof
	if item.asset == "bridge": sprite.z_index = -9
	return sprite
