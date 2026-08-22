class_name BuildingCatalog
extends Resource

@export var pieces: Array[BuildingPieceData] = []


func get_piece(piece_id: StringName) -> BuildingPieceData:
	for piece: BuildingPieceData in pieces:
		if piece != null and piece.piece_id == piece_id:
			return piece
	return null
