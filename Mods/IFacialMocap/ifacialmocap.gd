extends Mod_Base
class_name Mod_IFacialMocapController

#### iFacialMocap Developer Page:https://www.ifacialmocap.com/for-developer/ 
#### This is my attempt to convert the Unity script located at https://drive.google.com/file/d/10cnZRlglrHmZIv-ECT66eqNZNsiWhMtf/view?usp=sharing
#### to a format readable by Godot and for use with SnekStudio as a module. This script is written in GDScript to remain consistent and readable
#### with other module scripts. However, certain C# classes, such as CultureInfo or IPEndPoint, are not available here. It is also a little
#### more complicated to abort/kill Threads in Godot.
#### - There's also a lot of try/catch which GDScript doesn't have. Thinking of turning many of these functions into an Error return type.
#### - The original script has an OnEnable and OnDisable function. I made this script extend from Node3D to make use of the visibility_changed signal
#### and have the same functionality.

# broadcast address
@export var game_start_with_connect : bool = true
@export var ios_ip_address : String = "255.255.255.255"
var client : PacketPeerUDP
var start_flag : bool = true

#object names
@export var face_object_group_name : String = ""
@export var head_bone_name : String = ""
@export var right_eye_bone_name : String = ""
@export var left_eye_bone_name : String = ""
@export var head_position_object_name : String = ""

var udp : PacketPeerUDP
var thread : Thread
var mesh_target : MeshInstance3D
var mesh_target_list : Array[MeshInstance3D]
var head_object_array : Array[Node3D]
var right_eye_object_array : Array[Node3D]
var left_eye_object_array : Array[Node3D]
var head_position_object_array : Array[Node3D]

var message_string : String = ""
@export var local_port : int = 49983

func start_function():
	pass
	if start_flag == true:
		start_flag = false;
#
		find_nodes_inside_godot_settings()
#
		#Send to iOS
		if game_start_with_connect == true:
			connect_to_ios_app();
		#Recieve udp from iOS
		create_udp_server()

func _ready():
	start_function()
#
func create_udp_server():
	udp = PacketPeerUDP.new()
	#udp.Client.ReceiveTimeout = 5;
	#^^^ #TODO: Need an equivalent for the old timeout code. Here is a "poison pill" workaround found online (on the docs). Not sure how to implemnent.
		#udp.Client.ReceiveTimeout = 5;
		#socket.set_dest_address("127.0.0.1", 789)
		#socket.put_packet("Time to stop".to_ascii())
		#...
		#while socket.wait() == OK:
			#var data = socket.get_packet().get_string_from_ascii()
			#if data == "Time to stop":
				#return
	var err = udp.bind(local_port)
	if err != OK:
		print("Failed to bind UDP socket to port ", local_port)
		return

	thread = Thread.new()
	thread.start(thread_method)
	
	#NOTE: This is never used...?
	#IEnumerator WaitProcess(float WaitTime)
	#{
		#yield return new WaitForSeconds(WaitTime);
	#}

func connect_to_ios_app() -> void:
	#//iFacialMocap
	send_message_to_ios_app("iFacialMocap_sahuasouryya9218sauhuiayeta91555dy3719", 49983)
	#//Facemotion3d
	send_message_to_ios_app("FACEMOTION3D_OtherStreaming", 49993)

func stop_streaming_ios_app():
	send_message_to_ios_app("StopStreaming_FACEMOTION3D", 49993)

#iOSアプリに通信開始のメッセージを送信
#Send a message to the iOS application to start streaming
#TODO: Implement this as return Error for pseudo try/catch
func send_message_to_ios_app(send_message: String, send_port: int):

	client = PacketPeerUDP.new()
	client.connect_to_host(ios_ip_address, send_port)
	var dgram : PackedByteArray = client.get_string_from_utf8(send_message)
	client.put_var(dgram, dgram.size())
	client.put_var(dgram, dgram.size())
	client.put_var(dgram, dgram.size())
	client.put_var(dgram, dgram.size())
	client.put_var(dgram, dgram.size())

#NOTE: The original code said this is called once per frame, so I am assuming that it should be in physics_process.
func physics_process(delta : float):
	set_animation_inside_godot_settings()

#BlendShapeの設定
#set blendshapes
func set_blendshape_weight_from_str_array(str_array_b : Array[String]) -> void:
	var mapped_shape_name : String = str_array_b[0].replace("_R", "Right").replace("_L", "Left")
	#TODO: Need to find out how to get the Godot analog of Unity's CultureInfo (localization related). weight temporarily set to 0 for now.
	var weight : float
	if str_array_b[1].is_valid_float():
		weight = str_array_b[1].to_float()

	for mesh_target in mesh_target_list:
		var index : int = mesh_target.find_blend_shape_by_name(mapped_shape_name)
		if index > -1:
			mesh_target.set_blend_shape_value(index, weight)

#BlendShapeとボーンの回転の設定
#set blendshapes & bone rotation
#TODO: Implement this as return Error for pseudo try/catch
func set_animation_inside_godot_settings() -> void:
	var str_array_a : Array[String] = message_string.split('=');
#
	if str_array_a.size() >= 2:

		#blendShapes
		for message in str_array_a[0].split('|') as String:
			var str_array_b : Array[String] = ["", "", ""]
			if message.contains("&"):
				str_array_b = message.split('&')
			else:
				str_array_b = message.split('-')
			if str_array_b.size() == 2:
				set_blendshape_weight_from_str_array(str_array_b);

		for message in str_array_a[1].split('|') as String:
			var str_array_b : Array[String] = message.split('#')
			if str_array_b.size() == 2:

				var comma_list : Array[String] = str_array_b[1].split(',')
				if str_array_b[0] == "head":
					for head_object in head_object_array:
						#TODO: Quaternions spooky, check if I'm doing these correctly
						#TODO: Need trycatch using "is_valid_float()" on these for better safety.
						var new_rot : Vector3 = Vector3(comma_list[0].to_float(), -comma_list[1].to_float(), -comma_list[2].to_float())
						#NOTE: I have no idea if this is correct.
						head_object.transform.basis = Quaternion.from_euler(new_rot)

					for head_position_object in head_position_object_array:
						head_position_object.position = Vector3(-comma_list[3].to_float(), comma_list[4].to_float(), comma_list[5].to_float())

				elif str_array_b[0] == "rightEye":
					for right_eye_object in right_eye_object_array:
						var new_rot : Vector3 = Vector3(comma_list[0].to_float(), -comma_list[1].to_float(), comma_list[2].to_float())
						right_eye_object.transform.basis = Quaternion.from_euler(new_rot)

				elif str_array_b[0] == "leftEye":
					for left_eye_object in left_eye_object_array:
						var new_rot : Vector3 = Vector3(comma_list[0].to_float(), -comma_list[1].to_float(), comma_list[2].to_float())
						left_eye_object.transform.basis = Quaternion.from_euler(new_rot)

#TODO: Need that static class FM3D_and_iFacialMocap_GetAllChildren for this..
func find_nodes_inside_godot_settings():
	#Find BlendShape Objects
	mesh_target_list = Array[MeshInstance3D].new()

	var face_obj_grp : Node3D = get_tree().find_child(face_object_group_name, true)
	if face_obj_grp != null:
		#TODO: Convert
		var list : Array[Node3D] = get_all(face_obj_grp)

		for obj in list:
			if obj is MeshInstance3D:
				mesh_target = obj
			if mesh_target != null:
				if has_blend_shapes(mesh_target):
					mesh_target_list.append(mesh_target);

		#Find Bone Objects
		var head_object_array : Array[Node3D] 
		for head_string in head_bone_name.split(','):
			var head_object : Node3D = get_tree().find_child(head_string, true)
			if head_object != null:
				head_object_array.append(head_object)

		var right_eye_object_array : Array[Node3D]
		for right_eye_string in right_eye_bone_name.split(','):
			var right_eye_object : Node3D = get_tree().find_child(right_eye_string, true)
			if right_eye_object != null:
				right_eye_object_array.append(right_eye_object)

		var left_eye_object_array : Array[Node3D]
		for left_eye_string in left_eye_bone_name.split(','):
			var left_eye_object : Node3D = get_tree().find_child(left_eye_string, true)
			if left_eye_object != null:
				left_eye_object_array.append(left_eye_object)

		var head_position_object_array : Array[Node3D]
		for head_position_string in head_position_object_name.split(','):
			var head_position_object : Node3D = get_tree().find_child(head_position_string, true)
			if head_position_object != null:
				head_position_object_array.append(head_position_object)

func thread_method():
		#Process once every 5ms
		var next : int = Time.get_ticks_usec() + 50000
		var now : int
#
		#while true:
		#{
		#TODO: Try/catch here
			#try
			#{
			#NOTE: Not sure how to find this for Godot.
			#var remote_ep : IPEndPoint = null
			#byte[] data = udp.Receive(ref remote_ep);
			#message_string = Encoding.ASCII.GetString(data);
			#}
			#catch
			#{
			#}
#
			#do
			#{
				#now = DateTime.Now.Ticks;
			#}
			#while (now < next);
			#next += 50000;
		#}
	#}
#
#
func get_message_string() -> String:
	return message_string

#TODO: Need different trigger for this since Nodes don't have visibility. Unity script called this with OnEnable/OnDisabled
#func visibility_changed():
	#if visible:
		##TODO: try/catch
		#start_function()
#
	#else:
		##TODO: try/catch
		#on_application_quit()

func on_application_quit():
	#TODO: try/catch
	if start_flag == false:
		start_flag = true
		stop_udp()

func stop_udp():
	if game_start_with_connect == true:
		stop_streaming_ios_app()
	udp.free()
	thread.wait_to_finish()

func has_blend_shapes(skin : MeshInstance3D) -> bool:
	if !skin.mesh:
		return false

	if skin.get_blend_shape_count() <= 0:
		return false

	return true

#NOTE: ugh I don't know hoe to deal with these. I've separated the one static class into three static functions.
static func FM3D_and_iFacialMocap_GetAllChildren():
	pass
	

static func get_all(obj : Node3D) -> Array[Node3D]:
	return [null]
	#List<GameObject> allChildren = new List<GameObject>();
	#allChildren.Add(obj);
	#GetChildren(obj, ref allChildren);
	#return allChildren;
#}
#NOTE: The original script references 'ref' for all_children.
static func get_obj_children(obj : Node3D, all_children : Array[Node3D]):
	pass
#{	
	#children = obj.GetComponentInChildren<Transform>();
	#if (children.childCount == 0)
	#{
		#return;
	#}
	#foreach (Transform ob in children)
	#{
		#allChildren.Add(ob.gameObject);
		#GetChildren(ob.gameObject, ref allChildren);
	#}
	#}
#}
