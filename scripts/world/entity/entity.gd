class_name Entity
extends Node2D

enum Type {
	NONE,
	GENERIC,
	CROP,
	HARVESTABLE,
	PICKUP,
	NPC,
}

@export var type: Type = Type.GENERIC
