extends Node


#################### TESTING AI ####################
func ai_button_test_pressed() -> void: # Button has been pressed
    print("ai_manager.gd - ai_button_test_pressed() - Button for testing AI is pressed")
    test_ai.rpc_id(1) # Call the test_ai function on the server


@rpc("any_peer", "reliable")
func test_ai() -> void:
    if not multiplayer.is_server():
        return
    print("ai_manager.gd - test_ai() - Testing AI on server")

    # Get the player node
    # Start a sample Gemini conversation (mirrors python first call)
    var example_system := "You are the boss_test_controller. Keep responses concise."
    var example_chat_entry := "Hello, controller. Report current status."
    ai_setup_and_start(example_system, example_chat_entry)

@rpc("authority", "reliable")
func result_ai_call_from_server(result: String) -> void:
    print("ai_manager.gd - send_back_result_to_clients() - Displaying result from server")
    # Make sure the caller is the server
    var sender_id = multiplayer.get_remote_sender_id()
    if sender_id != 1:
        print("ai_manager.gd - result_ai_call_from_server() - Caller is not the server")
        return
    
    # Display the result in the UI
    EventBus.ai_response_received.emit(result)


#################### GEMINI INTEGRATION ####################

# https://aistudio.google.com/app/api-keys
const GEMINI_URL := "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

var gemini_api_key: String = ""
var gemini_system_instruction_text: String = ""
var gemini_messages: Array = [] # Array of { role: String, parts: [ { text: String } ] }

var _http: HTTPRequest

func _ready() -> void:
    EventBus.ai_test_button_pressed.connect(ai_button_test_pressed) # Connecting signal when button is pressed


    # Initialize HTTPRequest node and API key
    _http = HTTPRequest.new()
    add_child(_http)
    _http.request_completed.connect(_on_http_request_completed)

    # Load API key from environment or ProjectSettings (prefer env) - # https://aistudio.google.com/app/api-keys
    gemini_api_key = ""
    # gemini_api_key = OS.get_environment("GEMINI_API_KEY")
    if gemini_api_key.is_empty():
        if ProjectSettings.has_setting("ai/gemini_api_key"):
            gemini_api_key = str(ProjectSettings.get_setting("ai/gemini_api_key"))
        else:
            print("[GEMINI] Warning: No API key found. Set env GEMINI_API_KEY or ProjectSettings ai/gemini_api_key.")

func ai_setup_and_start(system_instruction_text: String, first_user_message: String) -> void:
    # Reset conversation and start with the first user message
    gemini_system_instruction_text = system_instruction_text
    gemini_messages.clear()
    _add_message(first_user_message, "user")
    _send_to_gemini()

func ai_send_user_message(user_text: String) -> void:
    _add_message(user_text, "user")
    _send_to_gemini()

func _add_message(text: String, role: String) -> void:
    var message := {
        "role": role,
        "parts": [ { "text": text } ]
    }
    gemini_messages.append(message)

func _build_payload() -> Dictionary:
    return {
        "system_instruction": {
            "parts": [ { "text": gemini_system_instruction_text } ]
        },
        "generationConfig": {
            "thinkingConfig": { "thinkingBudget": 0 }
        },
        "contents": gemini_messages
    }

func _send_to_gemini() -> void:
    if gemini_api_key.is_empty():
        EventBus.ai_request_failed.emit("Missing GEMINI_API_KEY. Configure it in environment or ProjectSettings.")
        return

    var headers := PackedStringArray([
        "Content-Type: application/json",
        "x-goog-api-key: %s" % gemini_api_key
    ])
    var body := JSON.stringify(_build_payload())

    var err := _http.request(GEMINI_URL, headers, HTTPClient.METHOD_POST, body)
    if err != OK:
        EventBus.ai_request_failed.emit("HTTPRequest error: %s" % error_string(err))

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var body_str := body.get_string_from_utf8()
    var parsed = JSON.parse_string(body_str)
    if typeof(parsed) != TYPE_DICTIONARY:
        EventBus.ai_request_failed.emit("Failed to parse response JSON")
        return

    var text := ""
    if parsed.has("candidates") and parsed["candidates"] is Array and parsed["candidates"].size() > 0:
        var candidate = parsed["candidates"][0]
        if candidate is Dictionary and candidate.has("content"):
            var content = candidate["content"]
            if content is Dictionary and content.has("parts") and content["parts"] is Array and content["parts"].size() > 0:
                var part0 = content["parts"][0]
                if part0 is Dictionary and part0.has("text"):
                    text = str(part0["text"]) 

    if text.is_empty():
        EventBus.ai_request_failed.emit("Empty response or unexpected schema. HTTP %s" % str(response_code))
        return

    # Append model reply to the conversation
    _add_message(text, "model")
    EventBus.ai_response_received.emit(text)
    result_ai_call_from_server.rpc(text) # call from server to all the clients to display the result in the UI
