extends Node

var server_endpoint = "https://exploitavoid.com/leaderboards/v1/api"
var leaderboard_id = 196
var leaderboard_secret = "70363f3ff5ccfa3b316ec2b4e3711d8e"

signal on_received_entries(entries)
signal on_received_user_entry(entry)
signal on_sent_user_value(was_success)

var request_entries_http_request : HTTPRequest
var request_user_entry_http_request : HTTPRequest
var send_user_value_http_request : HTTPRequest

func _ready():
	request_entries_http_request = HTTPRequest.new()
	add_child(request_entries_http_request)
	request_entries_http_request.request_completed.connect(_handle_received_entries)
	
	request_user_entry_http_request = HTTPRequest.new()
	add_child(request_user_entry_http_request)
	request_user_entry_http_request.request_completed.connect(_handle_received_user_entry)
	
	send_user_value_http_request = HTTPRequest.new()
	add_child(send_user_value_http_request)
	send_user_value_http_request.request_completed.connect(_handle_sent_user_value)
	
func request_entries(start: int = 1, count: int = 10) -> void:
	var url = server_endpoint + "/get_entries?leaderboard_id={0}&start={1}&count={2}"
	url = url.format([leaderboard_id,start,count])
	request_entries_http_request.request(url)
	
func request_user_entry(name: String) -> void:
	var url = server_endpoint + "/get_entries"
	var dict_to_serialize = {
		"leaderboard_id": leaderboard_id,
		"start": 1,
		"count": 1,
		"search": name
	}
	request_user_entry_http_request.request(url, PackedStringArray(), HTTPClient.METHOD_POST, JSON.stringify(dict_to_serialize))
	
# Value can be int or float, therefore no type definition
func send_user_value(name: String, value) -> void:
	var url = server_endpoint + "/update_entry"
	var dict_to_serialize = {
		"name": name,
		"value": value,
		"leaderboard_id": leaderboard_id
	}
	var upload_json = JSON.stringify(dict_to_serialize)
	var to_hash = "/update_entry" + upload_json + leaderboard_secret;
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(to_hash.to_utf8_buffer())
	var hash_result = ctx.finish()
	send_user_value_http_request.request(url, PackedStringArray(), HTTPClient.METHOD_POST, upload_json + hash_result.hex_encode())

# Example response: [{ "name": "Bob", "value": 40, "position": 1 }, { "name": "Steve", "value": 12, "position": 2 }]
func _handle_received_entries(_result, response_code, _headers, body) -> void:
	var entries = []
	if response_code == 200:
		entries = JSON.parse_string(body.get_string_from_utf8())
	on_received_entries.emit(entries)

# Example reponse: [{ "name": "Bob", "value": 40, "position": 1 }]
func _handle_received_user_entry(_result, response_code, _headers, body) -> void:
	var entry = null
	if response_code == 200:
		entry = JSON.parse_string(body.get_string_from_utf8())
	on_received_user_entry.emit(entry)
	
func _handle_sent_user_value(_result, response_code, _headers, _body) -> void:
	on_sent_user_value.emit(response_code == 200)
