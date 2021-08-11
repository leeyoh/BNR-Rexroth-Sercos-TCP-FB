
(* Rexroth SIP function block for Cs drives.  
	A maximum of 128 TCP sockets can be opened at a time. 
	Built on top of B&R TCP socket example
	
	8/11/2021 - John.L ( Inital development ) 
	Version 0.0 - Work in progress. 

	-------------- Parameters ------------- 
	ConnectTcp (Bool) : True - Enables the statemachine and starts TCP connection to Drive. 
								The functionblock will forever try to connect to the Drive, unless Connect is False. 
						False - Closes the connection. 

	Power (BOOL) : True - Sends the enable power control word to the drive. 
					False - Sends the disable power control word to the drive. 
					// If there was an error, the powerOn status will remain true, even though the power on the drive is off. 
					// Reset the Power to enable power again. 

	Velocity (REAL): If there is a difference between the prevous command the value is send.  
 
	IpAddress (String[80]): IpAddress of drive, currently '192.168.1.25', it can be configured on the drive panel, or through indraworks. 

	Port (UINT) : Client port, can be any of the non reserved ports. 

	DriveErrorReset (BOOL): TRUE - if there is a drive error, sends the reset drive error command. 
							FALSE - nothing, must be reset manually once DriveError is false.

	ErrorReset (BOOL): Does nothing yet, meant to reset TCP errors. 

	--------------- Returns --------------
	PowerOn (BOOL) : Power State of the drive. 

	ActVelocity (REAL) : ----

	ActCurrent (REAL) : ----

	Error (BOOL) : TODO//

	ReadyForOp (USINT[0..1]):  00: Control section and power section not ready for operation (e.g, drive error or phase 2)
								01: Control Section ready for operation (bb) 
								10: Control and power sections ready for operation (Ab) 
								11: Drive with torque (AF) 

	DriveError (BOOL) : ----
	DiagMsg (UDINT) : S-0-0390 for more details. 
	
	--------------- Internal --------------
	
*)

FUNCTION_BLOCK SIP
	IF ExternalPower THEN 
		PowerOn := Power; 
	END_IF 
	
	CASE _Client.sStep OF 
		
		// ============================== TCP Connection =================================//
		0: (*IDLE State waiting for Connect *) 
			IF ConnectTcp THEN
				_Client.sStep := 1;
			END_IF 
			
		1: (*Open Ethernet Interface *) 
			_Client.TcpOpen_0.enable := 1;	
			_Client.TcpOpen_0.pIfAddr := 0;  						(* Which Interface to open *)
			_Client.TcpOpen_0.port := Port;  						(* Port on client side to use *)
			_Client.TcpOpen_0.options := tcpOPT_REUSEADDR;	
			_Client.TcpOpen_0;  									(* Call the Function *)
			IF _Client.TcpOpen_0.status = 0 THEN  					(* TcpOpen successfull *)
				_Client.sStep := 5;											
			ELSIF _Client.TcpOpen_0.status = ERR_FUB_BUSY THEN  	(* TcpOpen not finished -> redo *)				
				(* Busy *)
			ELSE  													(* Goto Error Step *)
				_Client.sStep := 100;
			END_IF
		
		5: 	(*Setting Linger Parameter *) 
			_Client.linger_opt.lLinger := 0; 						(* linger Time = 0 *)
			_Client.linger_opt.lOnOff := 1; 						(* linger Option ON *)
			_Client.TcpIoctl_0.enable := 1;
			_Client.TcpIoctl_0.ident := _Client.TcpOpen_0.ident; 	(* Connection Ident from AsTP.TCP_Open *)
			_Client.TcpIoctl_0.ioctl := tcpSO_LINGER_SET; 			(* Set Linger Options *)
			_Client.TcpIoctl_0.pData := ADR(_Client.linger_opt);
			_Client.TcpIoctl_0.datalen := SIZEOF(_Client.linger_opt);
			_Client.TcpIoctl_0;	    
			IF _Client.TcpIoctl_0.status = 0 THEN  					(* TcpIoctl successfull *)
				_Client.sStep := 10;											
			ELSIF _Client.TcpIoctl_0.status = ERR_FUB_BUSY THEN  	(* TcpIoctl not finished -> redo *)				
				(* Busy *)
			ELSE  
				_Client.sStep := 100;								(* Goto Error Step *)
			END_IF
			
		10: (* Connect to the other Station *)					
			_Client.TcpClient_0.enable := 1;
			_Client.TcpClient_0.ident := _Client.TcpOpen_0.ident;  	(* Connection Ident from AsTCP.TCP_Open *)
			_Client.TcpClient_0.portserv := 35021;  				(* Port on server side to use *)
			_Client.TcpClient_0.pServer := ADR(IpAddress);  		(* Server Address *)
			_Client.TcpClient_0;  									(* Call the Function*)
			IF _Client.TcpClient_0.status = 0 THEN  				(* Open ok *)
				_Client.sStep := 60;	
				_Internal.ConnectSip := TRUE;
			ELSIF _Client.TcpClient_0.status = ERR_FUB_BUSY THEN  	(* TcpClient not finished -> redo *)	
				(* Busy *)
			ELSIF _Client.TcpClient_0.status = tcpERR_INVALID THEN  (* Port error -> Close actual connection, and reopen a new one *)
				_Client.sStep := 50;
			ELSE  													(* Goto Error Step *)
				_Client.sStep := 100;
			END_IF
			
		30: (* Write Data *) 	
			_Client.TcpSend_0.enable := 1;				
			_Client.TcpSend_0.ident := _Client.TcpOpen_0.ident;  		(* Connection Ident from AsTCP.TCP_Open *)
			_Client.TcpSend_0.pData := ADR(_Data.Send);  				(* Which data to send *)
			_Client.TcpSend_0.datalen := _Data.NumBytes;  				(* Lenght of data to send *)											
			_Client.TcpSend_0.flags := 0;
			_Client.TcpSend_0;  										(* Call the Function*)
			IF _Client.TcpSend_0.status = 0 THEN  						(* Data was sent sucessfully -> receive data *)
				_Client.sStep := 40;
			ELSIF _Client.TcpSend_0.status = ERR_FUB_BUSY THEN  		(* TcpSend not finished -> redo *)	
				(* Busy *)
			ELSIF (_Client.TcpSend_0.status = tcpERR_SENTLEN) OR 
				(_Client.TcpSend_0.status = tcpERR_NOT_CONNECTED) 
			THEN 														(* Connection Lost *)
				_Client.sStep := 50;
			ELSE  														(* Goto Error Step *)
				_Client.sStep := 100;
			END_IF	
			
		40: (* Recive Data *) 
			brsmemset(ADR(_Data.Receive),0,SIZEOF(_Data.Receive));		(* Clear the Receive Buffer *)
			_Client.TcpRecv_0.enable := 1;
			_Client.TcpRecv_0.ident := _Client.TcpOpen_0.ident;  		(* Connection Ident from AsTCP.TCP_Open *)
			_Client.TcpRecv_0.pData	:= ADR(_Data.Receive);  			(* Where to store the incoming data *)
			_Client.TcpRecv_0.datamax := SIZEOF(_Data.Receive); 		(* Lenght of data buffer *)
			_Client.TcpRecv_0.flags := 0;
			_Client.TcpRecv_0;  										(* Call the Function*)
			IF _Client.TcpRecv_0.status = 0 THEN  						(* Data was received sucessfully -> Send next packet *)
				_Client.sStep := 65;
				_Client.recv_timeout := 0;
			ELSIF _Client.TcpRecv_0.status = tcpERR_NO_DATA THEN  		(* No data received - wait *)
				_Client.recv_timeout := _Client.recv_timeout + 1;
				IF _Client.recv_timeout > 500 THEN
					_Client.sStep := 50;
					_Client.recv_timeout := 0;
				END_IF
				(* No Data received *)
			ELSIF _Client.TcpRecv_0.status = ERR_FUB_BUSY THEN  		(* TcpRecv not finished -> redo *)		
				(* Busy *)
			ELSIF _Client.TcpRecv_0.status = tcpERR_NOT_CONNECTED THEN			
				_Client.sStep := 50;								 	(* Connection Lost *)
			ELSE  (* Goto Error Step *)
				_Client.sStep := 100;
			END_IF
			
		50: (* Close connection *)
			_Client.TcpClose_0.enable := 1;
			_Client.TcpClose_0.ident := _Client.TcpOpen_0.ident;  	(* Connection Ident from AsTCP.TCP_Open *)
			_Client.TcpClose_0.how := 0;
			_Client.TcpClose_0;  									(* Call the Function*)
			IF _Client.TcpClose_0.status = 0 THEN  					(* Close sucessfull -> Reopen the interface *)
				_Client.sStep := 0;
			ELSIF _Client.TcpClose_0.status = ERR_FUB_BUSY THEN  	(* TcpClose not finished -> redo *)	
				(* Busy *)
			ELSE  													(* Goto Error Step *)
				_Client.sStep := 100;
			END_IF 
			
		// ============================== Rexroth States =================================//
		60: (* Idle State *)
			IF _Internal.Counter > 10 THEN
				_Internal.Counter := 0; 
			END_IF 
			CASE _Internal.Counter OF 
				0..5: // Reserved for Input from User 
					
					//TODO JL - Case for Power being set by external IO
					
					IF _Internal._SipConnected AND PowerOn AND NOT _Internal.StatusUpdate THEN 
						IF Velocity <> _Internal._Velocity THEN 
							_Client.sStep := 73;
						END_IF 
					END_IF 
					IF _Internal._SipConnected AND DriveError AND DriveErrorReset AND NOT _Internal.StatusUpdate THEN 
						_Client.sStep := 74;
					END_IF 
					IF _Internal._SipConnected AND Power AND NOT PowerOn AND NOT _Internal.StatusUpdate THEN
						_Client.sStep := 71;
					END_IF 					
					IF _Internal._SipConnected AND NOT Power AND PowerOn AND NOT _Internal.StatusUpdate THEN
						_Client.sStep := 72;
					END_IF 
					IF _Internal.ConnectSip AND NOT _Internal._SipConnected AND _Internal.AttemptCounter < 10 THEN 
						_Internal.AttemptCounter := _Internal.AttemptCounter + 1;
						_Client.sStep := 70;
					END_IF 
					IF (_Internal.ConnectSip AND NOT _Internal._SipConnected AND _Internal.AttemptCounter > 10) THEN 
						(* TODO: Error State *)	
					END_IF 
					IF NOT ConnectTcp THEN	
						_Client.sStep := 50; 
						_Internal.ConnectSip := FALSE;
						_Internal._SipConnected := FALSE; 
						_Internal.AttemptCounter := 0;
					END_IF 
				6:	//Read Diagnostic Message 
					IF _Internal._SipConnected THEN 
						_Client.sStep := 85;
					END_IF 
				7:	//Read Diagnostic State 
					IF _Internal._SipConnected THEN 
						_Client.sStep := 84;
					END_IF 
				8:	//Read the Current 
					IF _Internal._SipConnected THEN
						_Client.sStep := 83;
					END_IF 
				9: 	//Read the Velocity
					IF _Internal._SipConnected AND PowerOn THEN
						_Client.sStep := 82;
					END_IF 
				10:	//Read the Status 
					IF _Internal._SipConnected THEN  	
						_Client.sStep := 81;
					END_IF 
			END_CASE 
			_Internal.Counter := _Internal.Counter + 1;
			
		65: (* Parse State *) 
			_Client.sStep := 60;
			CASE _Data.Receive[1] OF 
				64: (* Connect *)
					_Internal._SipConnected := TRUE;
					_Internal.AttemptCounter := 0;	
				72:	(* Read Data Only*) 
					CASE _Data.Receive[0] OF 
						81: //Control Word
							_Internal.StatusUpdate := FALSE;
							PowerOn := (_Data.Receive[4] AND 256) = 256;
						82: //Velocity 
							ActVelocity := _Data.Receive[4] /10000.0;
						83: //Current 
							ActCurrent := _Data.Receive[4] / 1000.0;							
						84: //Diagnostic Status
							DriveReady := (_Data.Receive[4] AND 2) = 2;
							DriveError := (_Data.Receive[4] AND 8192) = 8192;
							ReadyForOp[0] := (_Data.Receive[4] AND 32768) = 32768;
							ReadyForOp[1] := (_Data.Receive[4] AND 16384) = 16384;
							_Internal.StatusUpdate := FALSE;
						85: //Diagnostic Message 
							DiagMsg := _Data.Receive[4];
					END_CASE	
				84: (* Write Data *) 	
					CASE _Data.Receive[0] OF 
						73: //Velocity Update 
							_Internal._Velocity := Velocity;
					END_CASE 	
				86: (* Write Data in Bits*) 
					CASE _Data.Receive[0] OF 
						71: //Power On 
							_Internal.StatusUpdate := TRUE;
						72: //Power Off
							_Internal.StatusUpdate := TRUE;
						74: //Error Reset 
							_Client.sStep := 75;
						75: //Error Reset Clear 
							_Internal.StatusUpdate := TRUE;
					END_CASE
			END_CASE 
			
			// ============================== User Inputs  =================================//	
		70: (* Connect Message *) 
			_Data.NumBytes := 20; 							// 5 * 4 Bytes per 
			_Data.Send[0] := 70;							// 1 is reserved for Connection
			_Data.Send[1] := 63;   							// Connection
			_Data.Send[2] := 1; 							// SIP Protocol Version 
			_Data.Send[3] := 30000; 						// Busy Timeout in Milli
			_Data.Send[4] := 30000; 						// Request Timeout in Milli
			_Client.sStep := 30;
		
		71: (* Power ON the Drive *)
			_Data.NumBytes := 24; 							//6 * 4 Bytes per 
			_Data.Send[0] := 71;							// Msg Number 
			_Data.Send[1] := 85;   							//Write Value
			_Data.Send[2] := 0; 							//Slave Index
			_Data.Send[3] := 145; 							//IDN
			_Data.Send[4] := 2; 							//Length of the data mask 
			_Data.BitMask := 256; 
			_Data.ControlWord := 256;
			_Data.Send[5] := _Data.ControlWord + SHL(_Data.BitMask,16); 
			_Client.sStep := 30;
			
		72: (* Power OFF the Drive *)
			_Data.NumBytes := 24; 							//6 * 4 Bytes per 
			_Data.Send[0] := 72;							//Msg Number 
			_Data.Send[1] := 85;   							//Write Value
			_Data.Send[2] := 0; 							//Slave Index
			_Data.Send[3] := 145; 							//IDN
			_Data.Send[4] := 2; 							//Length of the data mask 
			_Data.BitMask := 256; 
			_Data.ControlWord := 0;
			_Data.Send[5] := _Data.ControlWord + SHL(_Data.BitMask,16); 
			_Client.sStep := 30;
		
		73: (* Velocity Update *) 
			_Data.NumBytes := 24; 									//6 * 4 Bytes per 
			_Data.Send[0] := 73;
			_Data.Send[1] := 83;   									//Write Value
			_Data.Send[2] := 0; 									//Slave Index
			_Data.Send[3] := 37; 									//IDN
			_Data.Send[4] := 4; 									//Length of the data 
			_Data.Send[5] := REAL_TO_UDINT(Velocity * 10_000.0);	//scaled velocity
			_Client.sStep := 30;
			
		74: (* Drive Error Reset *) 
			_Data.NumBytes := 24; 							//6 * 4 Bytes per 
			_Data.Send[0] := 74;							//Msg Number 
			_Data.Send[1] := 85;   							//Write Value
			_Data.Send[2] := 0; 							//Slave Index
			_Data.Send[3] := 99; 							//IDN
			_Data.Send[4] := 2; 							//Length of the data mask 
			_Data.BitMask := 3; 
			_Data.ControlWord := 3;
			_Data.Send[5] := _Data.ControlWord + SHL(_Data.BitMask,16); 
			_Client.sStep := 30;
			
		75: (* Drive Error Reset 2*) 
			_Data.NumBytes := 24; 							//6 * 4 Bytes per 
			_Data.Send[0] := 75;							//Msg Number 
			_Data.Send[1] := 85;   							//Write Value
			_Data.Send[2] := 0; 							//Slave Index
			_Data.Send[3] := 99; 							//IDN
			_Data.Send[4] := 2; 							//Length of the data mask 
			_Data.BitMask := 3; 
			_Data.ControlWord := 0;
			_Data.Send[5] := _Data.ControlWord + SHL(_Data.BitMask,16); 
			_Client.sStep := 30;
			
		// ============================== System Output  =================================//		
		81: (* Read Control Word *) 
			_Data.NumBytes := 16; 	// 4 * 4 Bytes per 						
			_Data.Send[0] := 81;
			_Data.Send[1] := 71; 								
			_Data.Send[2] := 0; 	//Slave Index							
			_Data.Send[3] := 145;	//IDN
			_Client.sStep := 30;	
		
		82: (* Read the Velocity *) 
			_Data.NumBytes := 16; 	// 4 * 4 Bytes per 
			_Data.Send[0] := 82;
			_Data.Send[1] := 71; 	//Msg Type
			_Data.Send[2] := 0; 	//Slave Index
			_Data.Send[3] := 40;	//IDN
			_Client.sStep := 30;	
		
		83: (* Read the Current *) 
			_Data.NumBytes := 16; 	// 4 * 4 Bytes per 
			_Data.Send[0] := 83;
			_Data.Send[1] := 71; 	//Msg Type
			_Data.Send[2] := 0; 	//Slave Index
			_Data.Send[3] := 33208;	//IDN
			_Client.sStep := 30;	
		
		84: (* Read Diagnostic State *) 
			_Data.NumBytes := 16; 	// 4 * 4 Bytes per 						
			_Data.Send[0] := 84;
			_Data.Send[1] := 71; 								
			_Data.Send[2] := 0; 	//Slave Index							
			_Data.Send[3] := 32883;	//IDN
			_Client.sStep := 30;	
			
		85: (* Read Diagnostic Message *) 
			_Data.NumBytes := 16; 	// 4 * 4 Bytes per 						
			_Data.Send[0] := 85;
			_Data.Send[1] := 71; 								
			_Data.Send[2] := 0; 	//Slave Index							
			_Data.Send[3] := 390;	//IDN
			_Client.sStep := 30;
			
		100: (* Tcp Error State *)
			//TODO JL 
	
	END_CASE 
END_FUNCTION_BLOCK
