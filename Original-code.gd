extends Node

###########################################################
#
# ExtraSimple SMTP client
#
# 1 - import in your project
# 2 - put values in var server, user, password,
#		mailto, mymail
# 3 - call method Deliver(data) to send mail
#
###########################################################

###########################################################
#
#
# d: inner class for simple debug - begin
#
#
###########################################################

class d:
	var debug = true
	func display(data):
		if debug == true:
			prints ("debug:",data)

###########################################################
#
#
# d: inner class for simple debug - end
#
#
###########################################################


export var server = "smtp.xxx.com"
export var port	= 25
export var user = ""			# put userid for SMTP login
export var password = ""	# put password for SMTP login
export var mymailto = ""   # put destination address
export var mymail = ""		# put mail associated to userid/password

###########################################################
#
# signals
#
###########################################################

signal SMTP_connecting
signal SMTP_connected
signal SMTP_working
signal SMTP_disconnected_error
signal SMTP_disconnected_ok

###########################################################
#
# method used to connect
#
###########################################################

enum channel {TCP,PACKET}
export (channel) var com = PACKET

###########################################################
#
# storage area
#
###########################################################

var authloginbase64=""
var authpassbase64=""

var Socket = null
var PacketSocket = null
var PacketIn = ""
var PacketOut = ""

enum esi {OK,KO}    # i like that one!

enum stati {OK,WAITING,NO_RESPONSE,UNHANDLED_REPONSE}
export (stati) var stato

var MaxRetries = 5
var delayTime = 250

var thread = null

func _ready():
	if user != "":		authloginbase64=Marshalls.raw_to_base64(user.to_ascii())
	if password != "":	authpassbase64=Marshalls.raw_to_base64(password.to_ascii())


func _process(delta):
	pass

func Deliver(data):
	thread = Thread.new()
	thread.start(self,"ThreadDeliver",data)

func ThreadDeliver(data):
	var r_code
	emit_signal("SMTP_connecting")
	r_code = OpenSocket()
	if r_code == OK:
		r_code =WaitAnswer()
	if r_code == OK:
		emit_signal("SMTP_connected")
		r_code = send("ciao") # needed because some SMTP servers return error each first command
	if r_code == OK:
		r_code = MAILhello()
	if r_code == OK:
		emit_signal("SMTP_working")
		r_code = MAILauth()
	if r_code == OK:
		r_code = MAILfrom(mymail)
	if r_code == OK:
		r_code = MAILto(mymailto)
	if r_code == OK:
		r_code = MAILdata(data,mymail,"comanda per sagra")
	if r_code == OK:
		d.display("process OK")
	if r_code == OK:
		r_code =MAILquit()
	CloseSocket()
	if r_code == OK:
		emit_signal("SMTP_disconnected_ok")
	else:
		emit_signal("SMTP_disconnected_error")
		d.display("ERROR")
	return r_code


func OpenSocket():
	var error
	if Socket == null:
		Socket=StreamPeerTCP.new()
	error=Socket.connect_to_host(server,port)
	d.display(["connecting server...",server,error])
	if error > 0:
		var ip=IP.resolve_hostname(server)
		error=Socket.connect_to_host(ip,port)
		d.display(["trying IP ...",ip,error])

	for i in range(1,MaxRetries):
		if Socket.get_status() == Socket.STATUS_ERROR:
			d.display("Error while requesting connection")
			break
		elif Socket.get_status() == Socket.STATUS_CONNECTING:
			d.display("connecting...")
			break
		elif Socket.get_status() == Socket.STATUS_CONNECTED:
			d.display("connection up")
			break
		else:
			OS.delay_msec(delayTime)

	if com == PACKET:
		if PacketSocket == null:
			PacketSocket=PacketPeerStream.new()
			PacketSocket.set_stream_peer(Socket)

	return error

func CloseSocket():
	Socket.disconnect_from_host()

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
	d.display(["send",PacketOut])
	PacketOut = PacketOut + "\n"

	if com == PACKET:
		error=PacketSocket.put_packet(PacketOut.to_ascii())
	elif com == TCP:
		error=Socket.put_data(PacketOut.to_ascii())
		if error == null:
			error = "NULL"
	d.display(["send","r_code",error])
	return error

func WaitAnswer(succesful=""):
	stato=WAITING
	d.display(["waiting response from server..."])
	if com == PACKET:
		OS.delay_msec(delayTime)
		for i in range(1,MaxRetries):
			d.display(["bytes buffered",String(PacketSocket.get_available_packet_count()),"error",String(Socket.get_packet_error())])
			if PacketSocket.get_available_packet_count() > 0:
				PacketIn=PacketSocket.get_var()
				d.display(["receive",PacketIn])
				stato=OK
				break
			else:
				d.display(["waiting response from server...",i])
				OS.delay_msec(delayTime)
		if stato==WAITING:
			stato = NO_RESPONSE
		else:
			if ParsePacketIn(succesful) != OK:
				stato=UNHANDLED_REPONSE
		return stato
	elif com == TCP:
		PacketIn = ""
		OS.delay_msec(delayTime)
		for i in range(1,MaxRetries):
			var bufLen =Socket.get_available_bytes()
			if bufLen > 0:
				d.display(["bytes buffered",String(bufLen)])
				PacketIn=PacketIn + Socket.get_utf8_string(bufLen)
				d.display(["receive",PacketIn])
				break
			else:
				OS.delay_msec(delayTime)
		if PacketIn != "":
			stato=OK
			if ParsePacketIn(succesful) != OK:
				stato=UNHANDLED_REPONSE
		else:
			stato = NO_RESPONSE
		return stato
	else:
		return 99

func ParsePacketIn(strcompare):
	if strcompare == "":
		return OK
	if PacketIn.left(strcompare.length())==strcompare:
		return OK
	else:
		return KO

func MAILhello():
	var r_code=send("HELO", mymail)
	WaitAnswer()
	r_code= send("EHLO", mymail)
	r_code= WaitAnswer("250")
	return r_code

func MAILauth():
	var r_code=send("AUTH LOGIN")
	r_code=WaitAnswer("334")
	if r_code == OK:
		r_code=send(authloginbase64)
	r_code = WaitAnswer("334")
	if r_code == OK:
		r_code=send(authpassbase64)
	r_code = WaitAnswer("235")
	d.display(["r_code auth:",r_code])
	return r_code

func MAILfrom(data):
	var r_code=send("MAIL FROM:",bracket(data))
	r_code = WaitAnswer("250")
	return r_code

func MAILto(data):
	var r_code=send("RCPT TO:",bracket(data))
	r_code = WaitAnswer("250")
	return r_code

func MAILdata(data=null,from=null,subject=null):
	var corpo = ""
	for i in data:
		corpo = corpo + i + "\r\n"
	corpo=corpo + "."
	var r_code=send("DATA") #,bracket(data))
	r_code=WaitAnswer("354")
	if r_code == OK and from != null:
		r_code=send("FROM: ",bracket(from))
	if r_code == OK and subject != null:
		r_code=send("SUBJECT: ",subject)
	if r_code == OK and data != null:
		r_code=send(corpo)
	WaitAnswer("250")
	return r_code

func MAILquit():
	return send("QUIT")

func bracket(data):
	return "<"+data+">"
