(********************************************************************
 * COPYRIGHT -- Bernecker + Rainer
 ********************************************************************
 * Program: Server
 * File: Server.st
 * Author: Bernecker + Rainer
 * Created: February 21, 2008
 ********************************************************************
 * Implementation of program Server
 ********************************************************************)

PROGRAM _CYCLIC


	CASE Server.sStep OF
 	
		0:  (* Open Ethernet Interface *)
			Server.TcpOpen_0.enable := 1;	
			Server.TcpOpen_0.pIfAddr := 0;  (* Listen on all TCP/IP Interfaces*)
			Server.TcpOpen_0.port := 12000;  (* Port to listen*)
			Server.TcpOpen_0.options := 0;	
			Server.TcpOpen_0;  (* Call the Function*)
						
			IF Server.TcpOpen_0.status = 0 THEN  (* TcpOpen successfull*)
				Server.sStep := 5;	
			ELSIF Server.TcpOpen_0.status = ERR_FUB_BUSY THEN  (* TcpOpen not finished -> redo *)			
			  (* Busy *)	
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
		
		5:
			Server.linger_opt.lLinger := 0; (* linger Time = 0 *)
			Server.linger_opt.lOnOff := 1; (* linger Option ON *)
				 
		 	Server.TcpIoctl_0.enable := 1;
			Server.TcpIoctl_0.ident := Server.TcpOpen_0.ident; (* Connection Ident from AsTCP.TCP_Open *)
			Server.TcpIoctl_0.ioctl := tcpSO_LINGER_SET; (* Set Linger Options *)
			Server.TcpIoctl_0.pData := ADR(Server.linger_opt);
			Server.TcpIoctl_0.datalen := SIZEOF(Server.linger_opt);
   			Server.TcpIoctl_0;	    
		
			IF Server.TcpIoctl_0.status = 0 THEN  (* TcpIoctl successfull *)
				Server.sStep := 10;											
			ELSIF Server.TcpIoctl_0.status = ERR_FUB_BUSY THEN  (* TcpIoctl not finished -> redo *)				
			  (* Busy *)
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
		
		10: (* Wait for Client Connection *)
			Server.TcpServer_0.enable := 1;
			Server.TcpServer_0.ident := Server.TcpOpen_0.ident;  (* Connection Ident from AsTCP.TCP_Open *)
			Server.TcpServer_0.backlog := 1;  (* Number of clients waiting simultaneously for a connection*)
			Server.TcpServer_0.pIpAddr := ADR(Server.client_address);  (* Where to write the client IP-Address*)
			Server.TcpServer_0;  (* Call the Function*)
			
			IF Server.TcpServer_0.status = 0 THEN  (* Status = 0 if an client connects to server *)
				Server.sStep := 15;
			ELSIF Server.TcpServer_0.status = ERR_FUB_BUSY THEN  (* TcpServer not finished -> redo *)			
			  (* Busy *)	
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
			
			
		15:
		 	Server.TcpIoctl_0.enable := 1;
			Server.TcpIoctl_0.ident := Server.TcpServer_0.identclnt; (* Connection Ident from AsTCP.TCP_Server *)
			Server.TcpIoctl_0.ioctl := tcpSO_LINGER_SET;  (* Set Linger Options *)
			Server.TcpIoctl_0.pData := ADR(Server.linger_opt);
			Server.TcpIoctl_0.datalen := SIZEOF(Server.linger_opt);
   			Server.TcpIoctl_0;	    
		
			IF Server.TcpIoctl_0.status = 0 THEN  (* TcpIoctl successfull *)
				Server.sStep := 20;											
			ELSIF Server.TcpIoctl_0.status = ERR_FUB_BUSY THEN  (* TcpIoctl not finished -> redo *)				
			  (* Busy *)
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
			
		20: (* Wait for Data *)
			Server.TcpRecv_0.enable := 1;
			Server.TcpRecv_0.ident := Server.TcpServer_0.identclnt;  (* Client Ident from AsTCP.TCP_Server *)	
			Server.TcpRecv_0.pData	:= ADR(Server.data_buffer);  (* Where to store the incoming data *)
			Server.TcpRecv_0.datamax := SIZEOF(Server.data_buffer);  (* Lenght of data buffer *)
			Server.TcpRecv_0.flags := 0;
			Server.TcpRecv_0;  (* Call the Function*)
		
			IF Server.TcpRecv_0.status = 0 THEN  (* Data received *)
				Server.sStep := 30;
				Server.recv_timeout := 0;
			ELSIF Server.TcpRecv_0.status = tcpERR_NO_DATA THEN  (* No data received - wait *)
			   Server.recv_timeout := Server.recv_timeout + 1;
			  IF Server.recv_timeout > 50 THEN
	 		    Server.sStep := 40;
				Server.recv_timeout := 0;
			  END_IF
			ELSIF Server.TcpRecv_0.status = ERR_FUB_BUSY THEN  (* TcpRecv not finished -> redo *)					
			  (* Busy *)
			ELSIF Server.TcpRecv_0.status = tcpERR_NOT_CONNECTED THEN
				Server.sStep := 40;
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
		
			
		
		30:	(* Send Data back to Client *)	
			Server.TcpSend_0.enable := 1;				
			Server.TcpSend_0.ident := Server.TcpServer_0.identclnt;  (* Client Ident from AsTCP.TCP_Server *)	
			Server.TcpSend_0.pData := ADR(Server.data_buffer);  (* Which data to send *)
			Server.TcpSend_0.datalen := SIZEOF(Server.data_buffer);  (* Lenght of data to send *)					
			Server.TcpSend_0.flags := 0;
			Server.TcpSend_0;  (* Call the Function*)
				
			IF Server.TcpSend_0.status = 0 THEN  (* Data sent *)
				Server.sStep := 20;					   
			ELSIF Server.TcpSend_0.status = ERR_FUB_BUSY THEN  (* TcpSend not finished -> redo *)						
			  (* Busy *)
			ELSIF (Server.TcpSend_0.status = tcpERR_NOT_CONNECTED) THEN
				Server.sStep := 40;
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
			
		40:
			Server.TcpClose_0.enable := 1;
			Server.TcpClose_0.ident := Server.TcpServer_0.identclnt;
			Server.TcpClose_0.how := 0;; // tcpSHUT_RD OR tcpSHUT_WR;
			Server.TcpClose_0;
			
			IF Server.TcpClose_0.status = 0 THEN
   				Server.sStep := 50;
			ELSIF Server.TcpClose_0.status = ERR_FUB_BUSY THEN  (* TcpClose not finished -> redo *)	
			  (* Busy *)
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF	
		50: 
			Server.TcpClose_0.enable := 1;
			Server.TcpClose_0.ident := Server.TcpOpen_0.ident;
			Server.TcpClose_0.how := 0; //tcpSHUT_RD OR tcpSHUT_WR;
			Server.TcpClose_0;
			
			IF Server.TcpClose_0.status = 0 THEN
   				Server.sStep := 0;
			ELSIF Server.TcpClose_0.status = ERR_FUB_BUSY THEN  (* TcpClose not finished -> redo *)	
			  (* Busy *)
			ELSE  (* Goto Error Step *)
				Server.sStep := 100;
			END_IF
						
	    
		100:  (* Here some error Handling has to be implemented *)

	END_CASE
		



END_PROGRAM

