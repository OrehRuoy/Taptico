extends Node
## Spinner hub punch. Forwards to Chroma so there is one cache.


func punch(src: Texture2D, center_px: Vector2, radius_px: float) -> Texture2D:
	return Chroma.punch(src, center_px, radius_px)
