extends Node

## This looks like it was created by a CS student at a university graduation level,
## there are many fantastic code snippets here, please try and mine as much of it as you can, as I have.

# the debug function is quite smart.
var debug = true
func display(data):
	if debug == true:
		print("debug: ",data)

@export var server = "smtp.gmail.com" 		# you'll find info on the Gmail SMTP server at www.google.com :)
@export var port	= 465 	# standard SSL port
@export var user = ""	# put userid for SMTP login
@export var password = ""	# put password for SMTP login
@export var mymailto = ""	# put destination address
@export var mymail = "mail.smtp.localhost" 	# I found this at some random stackexchange thread


enum channel {TCP,PACKET}
@export var com: channel = channel.TCP

var Socket = null
var PacketSocket = null
var PacketIn = ""
var PacketOut = ""

enum esi {OK,KO}    

enum stati {OK,WAITING,NO_RESPONSE,UNHANDLED_REPONSE}
@export var stato: stati

var MaxRetries = 5
var delayTime = 250

var thread = null

var authloginbase64=""
var authpassbase64=""
func _ready():
	if user != "":	authloginbase64=Marshalls.raw_to_base64(user.to_ascii_buffer())
	if password != "":	authpassbase64=Marshalls.raw_to_base64(password.to_ascii_buffer())
  


# This is unbelievably useful. Try using ThreadDeliver without a thread for comparison
func Deliver(data):
	thread = Thread.new()
	thread.start(Callable(self,"ThreadDeliver"),data)


# If you want to debug the program, this is where you start
# I made a miniscule change to this function, which was actually extremely hard, and took a few days.
func ThreadDeliver(data):
	var r_code
	r_code = OpenSocket()
	if r_code == OK:
		r_code = WaitAnswer()
	if r_code == OK:
		r_code = MAILhello()
	if r_code == OK:
		print("SMTP_working")
		r_code = MAILauth()
	if r_code == OK:
		r_code = MAILfrom(mymail)
	if r_code == OK:
		r_code = MAILto(mymailto)
	if r_code == OK:
		r_code = MAILdata(data,mymail,subject)
	if r_code == OK:
		print("process OK")
	if r_code == OK:
		r_code =MAILquit()
	CloseSocket()
	if r_code == OK:
		display("All done")
	else:

		display("ERROR")
	return r_code

var Bocket = null
# I added the variable Bocket, as a wrap around the Socket (originally called socket anyway), 
# it's an SSL wrapper for Streampeers, I don't know much about these things, 
# but you learn a lot by messing around with things.
# I like creating silly names for variables, it keeps me motivated,
# reminds me that creating code is my choice, to do how I please. 


func OpenSocket():
	var error

	if Bocket == null:
		Bocket=StreamPeerTCP.new()
		error=Bocket.connect_to_host(server,port )
		Socket = StreamPeerSSL.new()
		Socket.connect_to_stream(Bocket, true, server)

	display(["connecting server...",server,error])

	if error > 0:
		var ip=IP.resolve_hostname(server)
		error=Socket.connect_to_host(ip,port)
		display(["trying IP ...",ip,error])

	for i in range(1,MaxRetries):
		print(Socket.get_status())

		if Socket.get_status() == Socket.STATUS_CONNECTED:
			display("connection up")
			break
		OS.delay_msec(delayTime)
	return error

func CloseSocket():
	Bocket.disconnect_from_host()

func send(data1,data2=null,data3=null):
	var error
	error = sendOnly(data1,data2,data3)
	return error

func sendOnly(data1,data2=null,data3=null):
	var error = 0
	PacketOut = data1
	if data2 != null:
		PacketOut = PacketOut + " " + data2
	if data3 != null:
		PacketOut = PacketOut + " " + data3
	display(["send",PacketOut])
	PacketOut = PacketOut + "\n"

	if com == channel.TCP:
		error=Socket.put_data(PacketOut.to_utf8_buffer())
		if error == null:
			error = "NULL"
	display(["send","r_code",error])
	return error

func WaitAnswer(succesful=""):
	stato= stati.WAITING
	display(["waiting response from server..."])
	if com == channel.TCP:
		PacketIn = ""
		OS.delay_msec(delayTime)
		for i in range(1,MaxRetries):
			Socket.poll()
			var bufLen = Socket.get_available_bytes()
			if bufLen > 0:
				display(["bytes buffered",str(bufLen)])
				PacketIn=PacketIn + Socket.get_utf8_string(bufLen)
				display(["receive",PacketIn])
				
				break
			else:
				OS.delay_msec(delayTime)
		if PacketIn != "":
			stato= stati.OK
			if ParsePacketIn(succesful) != OK:
				stato=stati.UNHANDLED_REPONSE
		else:
			stato = stati.NO_RESPONSE
		return stato
	else:
		return 99

func ParsePacketIn(strcompare):
	if strcompare == "":
		return OK
	if PacketIn.left(strcompare.length())==strcompare:
		return OK
	else:
		return FAILED

func MAILhello():
	var r_code=send("HELO", mymail)
	WaitAnswer()
	r_code= send("EHLO", mymail)
	r_code= WaitAnswer("250")
	return r_code

# the MAILauth() function was broken, I fixed it, you're welcome
func MAILauth():
	var r_code=send("AUTH LOGIN")
	r_code=WaitAnswer("334")
	
	#print("MAILauth()  , AUTH LOGIN ", r_code) 
  # when debugging, add print statements everywhere you fail to progress.

	if r_code == OK:
		r_code=send(authloginbase64)
	r_code = WaitAnswer("334")
	#print("MAILauth()  , username ", r_code)
	if r_code == OK:
		r_code=send(authpassbase64)
	r_code = WaitAnswer("235")
	#print("MAILauth()  , password ", r_code)
	display(["r_code auth:", r_code])
	return r_code


func MAILfrom(data):
	var r_code=send("MAIL FROM:",bracket(data))
	r_code = WaitAnswer("250")
	return r_code

func MAILto(data):
	var r_code=send("RCPT TO:",bracket(data))
	r_code = WaitAnswer("250")
	return r_code
	
var corpo = "Hello World!"
var subject = "New message from Godot"


func MAILdata(data=null,from=null,subject=null):

	print(corpo)
	for i in data:

		corpo = corpo + i  + "\r\n"

	var r_code=send("DATA") 
	r_code=WaitAnswer("354")
	if r_code == OK and subject != null:
		r_code=send("SUBJECT: ",subject)
	if r_code == OK and data != null:
		r_code=send(corpo)
	r_code =WaitAnswer("250")
	return r_code

func MAILquit():
	return send("QUIT")

func bracket(data):
	return "<"+data+">"



func _on_button_pressed() -> void:
	Deliver(".. ")
	# I still haven't figured out how to send a message without an extra dot at the end of the message
