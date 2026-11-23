@tool
extends EditorPlugin


const DEFAULT_PORT = 7777
const PROTOCOL_VERSION = "1.0"

var _server: TCPServer
var _clients: Array[StreamPeerTCP] = []
var _port: int = DEFAULT_PORT
var _enabled: bool = false


func _enter_tree() -> void:
	print("[MCP Runtime] Plugin loaded")
	add_autoload_singleton("MCPRuntime", "res://addons/godot_mcp_runtime/mcp_runtime_autoload.gd")


func _exit_tree() -> void:
	remove_autoload_singleton("MCPRuntime")
	print("[MCP Runtime] Plugin unloaded")
